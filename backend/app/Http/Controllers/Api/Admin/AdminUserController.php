<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\RoleName;
use App\Http\Controllers\Controller;
use App\Http\Resources\DeliveryResource;
use App\Http\Resources\UserResource;
use App\Models\Delivery;
use App\Models\Role;
use App\Models\User;
use App\Services\ActivityLogger;
use App\Services\NotificationService;
use App\Services\ReportService;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

/** User, role and driver management. */
class AdminUserController extends Controller
{
    /** GET /api/admin/users?search=&role=&status=&user_type= */
    public function index(Request $request): JsonResponse
    {
        $users = User::with(['role', 'driverProfile'])
            ->when($request->search, fn ($q, $s) => $q->where(fn ($w) => $w
                ->where('name', 'ilike', "%$s%")->orWhere('email', 'ilike', "%$s%")
                ->orWhere('university_id', 'ilike', "%$s%")->orWhere('phone', 'ilike', "%$s%")))
            ->when($request->role, fn ($q, $r) => $q->whereHas('role', fn ($w) => $w->where('name', $r)))
            ->when($request->status, fn ($q, $s) => $q->where('status', $s))
            ->when($request->user_type, fn ($q, $t) => $q->where('user_type', $t))
            ->when($request->verification, fn ($q, $v) => $q->whereHas('driverProfile', fn ($w) => $w->where('verification_status', $v)))
            ->latest()
            ->paginate($this->perPage(20));

        return $this->ok(UserResource::collection($users));
    }

    public function roles(): JsonResponse
    {
        return $this->ok(Role::orderBy('name')->get(['id', 'name', 'display_name', 'description']));
    }

    public function show(User $user): JsonResponse
    {
        return $this->ok(new UserResource($user->load(['role', 'driverProfile'])));
    }

    /** POST /api/admin/users — create any account (customer, driver, store owner, admin). */
    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);

        $user = DB::transaction(function () use ($data) {
            $user = User::create([
                'role_id' => Role::idFor($data['role']),
                'name' => $data['name'],
                'email' => strtolower($data['email']),
                'university_id' => isset($data['university_id']) ? strtoupper($data['university_id']) : null,
                'user_type' => $data['role'] === 'customer' ? ($data['user_type'] ?? 'student') : null,
                'phone' => $data['phone'] ?? null,
                'password' => $data['password'],
                'status' => $data['status'] ?? 'active',
            ]);
            $this->syncDriverProfile($user, $data);

            return $user;
        });

        ActivityLogger::log('user.created', "Admin created {$data['role']} account {$user->email}", $user);

        return $this->created(new UserResource($user->load(['role', 'driverProfile'])), 'Account created.');
    }

    /** PUT /api/admin/users/{id} — edit info and/or assign a role. */
    public function update(Request $request, User $user): JsonResponse
    {
        $data = $this->validated($request, $user);

        if (isset($data['role']) && $user->id === $request->user()->id && $data['role'] !== 'admin') {
            throw ValidationException::withMessages(['role' => 'You cannot remove your own admin role.']);
        }

        DB::transaction(function () use ($user, $data) {
            $fields = collect($data)->only(['name', 'email', 'university_id', 'user_type', 'phone', 'status'])->all();
            if (! empty($data['password'])) {
                $fields['password'] = $data['password'];
            }
            if (isset($data['role'])) {
                $fields['role_id'] = Role::idFor($data['role']);
            }
            $user->update($fields);
            $this->syncDriverProfile($user->fresh('role'), $data);
        });

        ActivityLogger::log('user.updated', "Admin updated {$user->email}", $user, array_keys($data));

        return $this->ok(new UserResource($user->fresh(['role', 'driverProfile'])), 'User updated.');
    }

    /** PATCH /api/admin/users/{id}/status {status: active|suspended} */
    public function updateStatus(Request $request, User $user): JsonResponse
    {
        $request->validate(['status' => ['required', 'in:active,suspended']]);
        if ($user->id === $request->user()->id) {
            throw ValidationException::withMessages(['status' => 'You cannot suspend your own account.']);
        }

        $user->update(['status' => $request->status]);
        if ($request->status === 'suspended') {
            $user->tokens()->delete(); // sign out everywhere
            $user->driverProfile?->update(['is_online' => false]);
        }
        ActivityLogger::log('user.'.$request->status, "{$user->email} {$request->status}", $user);

        return $this->ok(new UserResource($user->load(['role', 'driverProfile'])), $request->status === 'active' ? 'Account activated.' : 'Account suspended.');
    }

    /** PATCH /api/admin/drivers/{user}/verification {verification_status: verified|rejected|pending} */
    public function verifyDriver(Request $request, User $user, NotificationService $notifications): JsonResponse
    {
        $request->validate(['verification_status' => ['required', 'in:verified,rejected,pending']]);
        abort_unless($user->hasRole(RoleName::Driver) && $user->driverProfile, 422, 'This user is not a driver.');

        $verified = $request->verification_status === 'verified';
        $user->driverProfile->update([
            'verification_status' => $request->verification_status,
            'verified_at' => $verified ? now() : null,
            'verified_by' => $verified ? $request->user()->id : null,
            'is_online' => $verified ? $user->driverProfile->is_online : false,
        ]);

        $notifications->notify($user, 'driver_verification',
            $verified ? 'You are verified!' : 'Driver verification update',
            $verified ? 'Your RUPP Eat driver account is verified. Go online to start receiving deliveries.'
                : 'Your driver account was not approved. Please contact the RUPP Eat administrator.');
        ActivityLogger::log('driver.'.$request->verification_status, "Driver {$user->name} {$request->verification_status}", $user);

        return $this->ok(new UserResource($user->load(['role', 'driverProfile'])), 'Driver verification updated.');
    }

    /** PATCH /api/admin/drivers/{user}/active {is_active: bool} */
    public function setDriverActive(Request $request, User $user): JsonResponse
    {
        $request->validate(['is_active' => ['required', 'boolean']]);
        abort_unless($user->driverProfile, 422, 'This user is not a driver.');

        $user->driverProfile->update([
            'is_active' => $request->boolean('is_active'),
            'is_online' => $request->boolean('is_active') && $user->driverProfile->is_online,
        ]);
        ActivityLogger::log('driver.'.($request->boolean('is_active') ? 'activated' : 'deactivated'), "Driver {$user->name}", $user);

        return $this->ok(new UserResource($user->load(['role', 'driverProfile'])), 'Driver updated.');
    }

    /** GET /api/admin/drivers/{user}/deliveries — history + performance. */
    public function driverDeliveries(Request $request, User $user, ReportService $reports): JsonResponse
    {
        $deliveries = Delivery::where('driver_id', $user->id)
            ->with(['order.items', 'order.store.building', 'order.customer'])
            ->latest()
            ->paginate($this->perPage(20));

        $perf = collect($reports->driverPerformance(CarbonImmutable::create(2000), CarbonImmutable::now()))
            ->firstWhere('driver_id', $user->id);

        $response = $this->ok(DeliveryResource::collection($deliveries))->getData(true);
        $response['performance'] = $perf;

        return response()->json($response);
    }

    private function validated(Request $request, ?User $user = null): array
    {
        $req = $user ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$req, 'string', 'max:100'],
            'email' => [$req, 'email:rfc', 'max:150', Rule::unique('users', 'email')->ignore($user?->id)],
            'university_id' => ['nullable', 'string', 'max:50', Rule::unique('users', 'university_id')->ignore($user?->id)],
            'user_type' => ['nullable', 'in:student,lecturer,staff'],
            'phone' => ['nullable', 'string', 'regex:/^\+?[0-9 ]{8,15}$/'],
            'role' => [$req, Rule::in(array_map(fn ($r) => $r->value, RoleName::cases()))],
            'status' => ['sometimes', 'in:active,suspended'],
            'password' => [$user ? 'nullable' : 'required', Password::min(8)->letters()->numbers()],
            'vehicle_type' => ['nullable', 'in:motorbike,bicycle,walking'],
            'plate_number' => ['nullable', 'string', 'max:30'],
            'national_id' => ['nullable', 'string', 'max:50'],
            'verification_status' => ['nullable', 'in:pending,verified,rejected'],
        ]);
    }

    private function syncDriverProfile(User $user, array $data): void
    {
        if (! $user->hasRole(RoleName::Driver)) {
            return;
        }
        $profile = $user->driverProfile()->firstOrNew();
        $profile->fill(collect($data)->only(['vehicle_type', 'plate_number', 'national_id'])->filter(fn ($v) => $v !== null)->all());
        if (! empty($data['verification_status'])) {
            $profile->verification_status = $data['verification_status'];
            $profile->verified_at = $data['verification_status'] === 'verified' ? now() : null;
            $profile->verified_by = $data['verification_status'] === 'verified' ? auth()->id() : null;
        }
        $profile->save();
    }
}
