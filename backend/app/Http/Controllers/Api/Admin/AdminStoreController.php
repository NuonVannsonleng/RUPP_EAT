<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\RoleName;
use App\Http\Controllers\Controller;
use App\Http\Resources\StoreResource;
use App\Models\Role;
use App\Models\Store;
use App\Models\StoreApplication;
use App\Models\User;
use App\Services\ActivityLogger;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/** Store monitoring and the store application (onboarding) workflow. */
class AdminStoreController extends Controller
{
    /** GET /api/admin/stores?search=&status= — all stores with activity numbers. */
    public function index(Request $request): JsonResponse
    {
        $stores = Store::with(['building', 'owner'])
            ->withCount(['products', 'orders', 'orders as orders_today_count' => fn ($q) => $q->whereDate('created_at', today())])
            ->withSum(['orders as revenue' => fn ($q) => $q->whereIn('status', ['delivered', 'picked_up'])], 'total')
            ->when($request->search, fn ($q, $s) => $q->where('name', 'ilike', "%$s%"))
            ->when($request->status, fn ($q, $s) => $q->where('status', $s))
            ->orderBy('name')
            ->paginate($this->perPage(20));

        $stores->getCollection()->transform(function ($store) use ($request) {
            return array_merge((new StoreResource($store))->resolve($request), [
                'orders_today' => $store->orders_today_count,
                'revenue' => round((float) $store->revenue, 2),
            ]);
        });

        return $this->paged($stores);
    }

    /** PATCH /api/admin/stores/{id}/status {status: active|suspended} */
    public function updateStatus(Request $request, Store $store): JsonResponse
    {
        $request->validate(['status' => ['required', 'in:active,suspended'], 'reason' => ['nullable', 'string', 'max:255']]);
        $store->update(['status' => $request->status]);
        ActivityLogger::log('store.'.$request->status, "Store {$store->name} {$request->status}", $store, ['reason' => $request->reason]);

        return $this->ok(new StoreResource($store->load(['building', 'owner'])), $request->status === 'active' ? 'Store activated.' : 'Store suspended.');
    }

    public function destroy(Store $store): JsonResponse
    {
        if ($store->orders()->whereIn('status', ['pending', 'accepted', 'preparing', 'ready', 'driver_assigned', 'on_the_way'])->exists()) {
            throw ValidationException::withMessages(['store' => 'This store still has active orders.']);
        }
        $store->delete();
        ActivityLogger::log('store.deleted', "Store {$store->name} deleted", $store);

        return $this->ok(null, 'Store deleted.');
    }

    // ---------- Applications ----------

    /** POST /api/store-applications — public "open a store on RUPP Eat" form. */
    public function apply(Request $request): JsonResponse
    {
        $data = $request->validate([
            'applicant_name' => ['required', 'string', 'max:100'],
            'applicant_email' => ['required', 'email:rfc', 'max:150'],
            'applicant_phone' => ['required', 'string', 'regex:/^\+?[0-9 ]{8,15}$/'],
            'store_name' => ['required', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:1000'],
            'building_id' => ['nullable', 'uuid', 'exists:buildings,id'],
            'location_note' => ['nullable', 'string', 'max:200'],
        ]);

        if (StoreApplication::where('applicant_email', strtolower($data['applicant_email']))->where('status', 'pending')->exists()) {
            throw ValidationException::withMessages(['applicant_email' => 'You already have a pending application.']);
        }

        $application = StoreApplication::create([...$data, 'applicant_email' => strtolower($data['applicant_email']), 'applicant_id' => $request->user()?->id]);

        return $this->created(['id' => $application->id, 'status' => $application->status], 'Application submitted. The RUPP Eat team will review it soon.');
    }

    public function applications(Request $request): JsonResponse
    {
        $apps = StoreApplication::with(['building', 'reviewer:id,name', 'store:id,name'])
            ->when($request->status, fn ($q, $s) => $q->where('status', $s))
            ->latest()
            ->paginate($this->perPage(20));

        return $this->paged($apps);
    }

    /**
     * POST /api/admin/store-applications/{id}/approve
     * Creates (or reuses) the store-owner account and the store, in one transaction.
     * Returns a temporary password when a new account is created.
     */
    public function approve(Request $request, StoreApplication $application, NotificationService $notifications): JsonResponse
    {
        if ($application->status !== 'pending') {
            throw ValidationException::withMessages(['application' => 'This application was already reviewed.']);
        }
        $request->validate(['opening_time' => ['nullable', 'date_format:H:i'], 'closing_time' => ['nullable', 'date_format:H:i'], 'note' => ['nullable', 'string', 'max:255']]);

        $tempPassword = null;
        [$store, $owner] = DB::transaction(function () use ($application, $request, &$tempPassword) {
            $owner = User::with('role')->where('email', $application->applicant_email)->first();
            if ($owner && ! $owner->hasRole(RoleName::StoreOwner)) {
                if ($owner->hasRole(RoleName::Admin)) {
                    throw ValidationException::withMessages(['application' => 'This email belongs to an admin account.']);
                }
                $owner->update(['role_id' => Role::idFor(RoleName::StoreOwner->value)]);
            }
            if (! $owner) {
                $tempPassword = 'Rupp'.random_int(100000, 999999);
                $owner = User::create([
                    'role_id' => Role::idFor(RoleName::StoreOwner->value),
                    'name' => $application->applicant_name,
                    'email' => $application->applicant_email,
                    'phone' => $application->applicant_phone,
                    'password' => $tempPassword,
                ]);
            }

            $slug = Str::slug($application->store_name) ?: 'store';
            $base = $slug;
            for ($i = 2; Store::withTrashed()->where('slug', $slug)->exists(); $i++) {
                $slug = "$base-$i";
            }

            $store = Store::create([
                'owner_id' => $owner->id,
                'building_id' => $application->building_id,
                'name' => $application->store_name,
                'slug' => $slug,
                'description' => $application->description,
                'location_note' => $application->location_note,
                'phone' => $application->applicant_phone,
                'opening_time' => $request->input('opening_time', '07:00'),
                'closing_time' => $request->input('closing_time', '17:00'),
                'status' => 'active',
                'is_open' => false, // owner opens it after setting up the menu
            ]);

            $application->update([
                'status' => 'approved', 'store_id' => $store->id, 'applicant_id' => $owner->id,
                'reviewed_by' => $request->user()->id, 'reviewed_at' => now(), 'review_note' => $request->note,
            ]);

            return [$store, $owner];
        });

        $notifications->notify($owner, 'store_approved', 'Store approved', "{$store->name} is approved on RUPP Eat. Add your menu and open the store from the dashboard.");
        ActivityLogger::log('store.approved', "Store application {$store->name} approved", $store);

        return $this->ok([
            'store' => (new StoreResource($store->load(['building', 'owner'])))->resolve($request),
            'owner_email' => $owner->email,
            // Shown once to the admin so they can hand it to the owner. Owner should change it after first login.
            'temporary_password' => $tempPassword,
        ], 'Application approved and store created.');
    }

    public function reject(Request $request, StoreApplication $application): JsonResponse
    {
        $request->validate(['note' => ['required', 'string', 'max:255']]);
        if ($application->status !== 'pending') {
            throw ValidationException::withMessages(['application' => 'This application was already reviewed.']);
        }
        $application->update(['status' => 'rejected', 'review_note' => $request->note, 'reviewed_by' => $request->user()->id, 'reviewed_at' => now()]);
        ActivityLogger::log('store.application_rejected', "Store application {$application->store_name} rejected", $application);

        return $this->ok($application, 'Application rejected.');
    }
}
