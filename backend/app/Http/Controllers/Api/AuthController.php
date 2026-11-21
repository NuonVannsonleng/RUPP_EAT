<?php

namespace App\Http\Controllers\Api;

use App\Enums\RoleName;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterDriverRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Services\NotificationService;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Requests\Auth\UpdateProfileRequest;
use App\Http\Resources\UserResource;
use App\Models\Role;
use App\Models\Store;
use App\Models\User;
use App\Services\ActivityLogger;
use App\Support\Media;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = User::create([
            'role_id' => Role::idFor(RoleName::Customer->value),
            'name' => $request->name,
            'email' => strtolower($request->email),
            'university_id' => strtoupper($request->university_id),
            'user_type' => $request->user_type,
            'phone' => $request->phone,
            'password' => $request->password, // hashed by the model cast
            'last_login_at' => now(),
        ]);

        ActivityLogger::log('user.registered', "{$user->name} registered", $user, [], $user->id);

        return $this->created($this->authPayload($user, $request->device_name ?? 'mobile'), 'Welcome to RUPP Eat!');
    }

    /**
     * POST /api/register/driver — a campus driver applies in the mobile app.
     * They can log in immediately but stay offline until an admin verifies them.
     */
    public function registerDriver(RegisterDriverRequest $request, NotificationService $notifications): JsonResponse
    {
        $user = DB::transaction(function () use ($request) {
            $user = User::create([
                'role_id' => Role::idFor(RoleName::Driver->value),
                'name' => $request->name,
                'email' => strtolower($request->email),
                'university_id' => $request->university_id ? strtoupper($request->university_id) : null,
                'phone' => $request->phone,
                'password' => $request->password,
                'last_login_at' => now(),
            ]);
            $user->driverProfile()->create([
                'vehicle_type' => $request->vehicle_type,
                'plate_number' => $request->plate_number,
                'national_id' => $request->national_id,
                'verification_status' => 'pending',
                'is_active' => true,
                'is_online' => false,
            ]);

            return $user;
        });

        foreach (User::whereHas('role', fn ($q) => $q->where('name', RoleName::Admin->value))->get() as $admin) {
            $notifications->notify($admin, 'driver_application', 'New driver to verify',
                "{$user->name} ({$request->vehicle_type}) registered as a driver and is waiting for verification.",
                ['driver_id' => $user->id]);
        }
        ActivityLogger::log('driver.registered', "{$user->name} registered as a driver", $user, [], $user->id);

        return $this->created($this->authPayload($user, $request->device_name ?? 'mobile'),
            'Driver account created. An administrator will verify you before you can go online.');
    }

    /** Log in with email OR student/staff ID. */
    public function login(LoginRequest $request): JsonResponse
    {
        $login = trim($request->login);
        $user = User::with('role')
            ->where(fn ($q) => $q->where('email', strtolower($login))->orWhere('university_id', strtoupper($login)))
            ->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages(['login' => 'These credentials do not match our records.']);
        }
        if (! $user->isActive()) {
            throw ValidationException::withMessages(['login' => 'Your account is suspended. Please contact RUPP Eat support.']);
        }

        // The web dashboard is for admins and store owners; the mobile app is for customers and drivers.
        $allowed = $request->app === 'dashboard'
            ? [RoleName::Admin->value, RoleName::StoreOwner->value]
            : [RoleName::Customer->value, RoleName::Driver->value];
        if ($request->app && ! in_array($user->role->name, $allowed, true)) {
            $where = $request->app === 'dashboard' ? 'the RUPP Eat mobile app' : 'the RUPP Eat web dashboard';
            throw ValidationException::withMessages(['login' => "This account is a {$user->role->display_name} account. Please sign in on $where."]);
        }

        $user->update(['last_login_at' => now()]);
        ActivityLogger::log('user.login', "{$user->name} logged in", $user, [], $user->id);

        return $this->ok($this->authPayload($user, $request->device_name ?? ($request->app ?? 'api')), 'Logged in successfully.');
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->update(['fcm_token' => null]);
        $request->user()->currentAccessToken()?->delete();

        return $this->ok(null, 'Logged out.');
    }

    public function me(Request $request): JsonResponse
    {
        return $this->ok($this->userData($request->user()));
    }

    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->safe()->only(['name', 'email', 'phone']);

        if ($request->hasFile('avatar')) {
            $data['avatar_path'] = Media::replace($user->avatar_path, $request->file('avatar'), 'avatars');
        }
        $user->update($data);

        if ($user->hasRole(RoleName::Driver) && $user->driverProfile) {
            $user->driverProfile->update($request->safe()->only(['vehicle_type', 'plate_number']));
        }

        return $this->ok($this->userData($user->fresh()), 'Profile updated.');
    }

    public function changePassword(ChangePasswordRequest $request): JsonResponse
    {
        $user = $request->user();
        $user->update(['password' => $request->password]);
        // Sign out every other device.
        $user->tokens()->where('id', '!=', $user->currentAccessToken()->id)->delete();

        return $this->ok(null, 'Password changed.');
    }

    /** Sends a 6-digit reset code by email. Always answers the same way to avoid account enumeration. */
    public function forgotPassword(Request $request): JsonResponse
    {
        $request->validate(['email' => ['required', 'email']]);
        $user = User::where('email', strtolower($request->email))->first();

        if ($user && $user->isActive()) {
            $code = (string) random_int(100000, 999999);
            DB::table('password_reset_tokens')->updateOrInsert(
                ['email' => $user->email],
                ['token' => Hash::make($code), 'created_at' => now()]
            );
            Mail::raw("Your RUPP Eat password reset code is $code. It expires in 15 minutes.", function ($m) use ($user) {
                $m->to($user->email)->subject('RUPP Eat password reset code');
            });
        }

        return $this->ok(null, 'If that email is registered, a 6-digit reset code has been sent.');
    }

    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $email = strtolower($request->email);
        $row = DB::table('password_reset_tokens')->where('email', $email)->first();

        if (! $row || now()->diffInMinutes($row->created_at, true) > 15 || ! Hash::check($request->code, $row->token)) {
            throw ValidationException::withMessages(['code' => 'The reset code is invalid or has expired.']);
        }

        $user = User::where('email', $email)->firstOrFail();
        $user->update(['password' => $request->password]);
        $user->tokens()->delete();
        DB::table('password_reset_tokens')->where('email', $email)->delete();

        return $this->ok(null, 'Password reset. You can now log in.');
    }

    public function updateFcmToken(Request $request): JsonResponse
    {
        $request->validate(['fcm_token' => ['nullable', 'string', 'max:500']]);
        $request->user()->update(['fcm_token' => $request->fcm_token]);

        return $this->ok(null, 'Push token saved.');
    }

    private function authPayload(User $user, string $device): array
    {
        return [
            'token' => $user->createToken($device)->plainTextToken,
            'token_type' => 'Bearer',
            'user' => $this->userData($user),
        ];
    }

    private function userData(User $user): array
    {
        $user->loadMissing(['role', 'driverProfile']);
        if ($user->hasRole(RoleName::StoreOwner)) {
            $user->managed_stores = Store::whereIn('id', $user->managedStoreIds())
                ->get(['id', 'name', 'logo_path', 'status'])
                ->map(fn ($s) => ['id' => $s->id, 'name' => $s->name, 'logo_url' => Media::url($s->logo_path), 'status' => $s->status]);
        }

        return (new UserResource($user))->resolve(request());
    }
}
