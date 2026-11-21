<?php

namespace App\Http\Controllers\Api\Driver;

use App\Enums\DeliveryStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\DeliveryResource;
use App\Models\Delivery;
use App\Services\DeliveryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/** Driver-only endpoints. Drivers can see open requests and the deliveries assigned to them, nothing else. */
class DriverController extends Controller
{
    private const WITH = ['order.items', 'order.store.building', 'order.customer'];

    public function __construct(private DeliveryService $deliveries) {}

    /** GET /api/driver/dashboard */
    public function dashboard(Request $request): JsonResponse
    {
        $driver = $request->user();
        $profile = $driver->driverProfile;

        // Columns are table-qualified: the earnings sums join `orders`, which also has driver_id and status.
        $mine = Delivery::where('deliveries.driver_id', $driver->id);
        $todayDelivered = (clone $mine)->where('deliveries.status', DeliveryStatus::Delivered)->whereDate('deliveries.delivered_at', today());
        $active = (clone $mine)->whereIn('deliveries.status', DeliveryStatus::active())->with(self::WITH)->orderBy('deliveries.assigned_at')->get();

        $earningsToday = (float) (clone $todayDelivered)->join('orders', 'orders.id', '=', 'deliveries.order_id')->sum('orders.delivery_fee');
        $weekDelivered = (clone $mine)->where('deliveries.status', DeliveryStatus::Delivered)->where('deliveries.delivered_at', '>=', now()->startOfWeek());

        return $this->ok([
            'profile' => [
                'is_online' => (bool) $profile?->is_online,
                'verification_status' => $profile?->verification_status ?? 'pending',
                'is_active' => (bool) $profile?->is_active,
                'vehicle_type' => $profile?->vehicle_type,
            ],
            'stats' => [
                'today_deliveries' => (clone $todayDelivered)->count(),
                'today_earnings' => round($earningsToday, 2),
                'week_deliveries' => (clone $weekDelivered)->count(),
                'week_earnings' => round((float) (clone $weekDelivered)->join('orders', 'orders.id', '=', 'deliveries.order_id')->sum('orders.delivery_fee'), 2),
                'total_deliveries' => (clone $mine)->where('status', DeliveryStatus::Delivered)->count(),
                'available_requests' => $profile?->canReceiveRequests() ? $this->deliveries->availableFor($driver)->count() : 0,
            ],
            'active_deliveries' => DeliveryResource::collection($active)->resolve($request),
        ]);
    }

    /** POST /api/driver/availability {is_online: bool} */
    public function availability(Request $request): JsonResponse
    {
        $request->validate(['is_online' => ['required', 'boolean']]);
        $profile = $request->user()->driverProfile;

        if (! $profile) {
            abort(403, 'Driver profile not found.');
        }
        if ($request->boolean('is_online') && (! $profile->isVerified() || ! $profile->is_active)) {
            throw ValidationException::withMessages(['is_online' => $profile->isVerified()
                ? 'Your driver account is deactivated. Please contact the administrator.'
                : 'Your driver account is waiting for administrator verification.']);
        }

        $profile->update([
            'is_online' => $request->boolean('is_online'),
            'last_online_at' => $request->boolean('is_online') ? now() : $profile->last_online_at,
        ] + ($request->boolean('is_online') ? [] : ['current_latitude' => null, 'current_longitude' => null, 'current_heading' => null]));

        return $this->ok(['is_online' => $profile->is_online], $profile->is_online ? 'You are online.' : 'You are offline.');
    }

    /**
     * GET /api/driver/deliveries?type=available|active|completed|cancelled|history
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate(['type' => ['nullable', Rule::in(['available', 'active', 'completed', 'cancelled', 'history'])]]);
        $driver = $request->user();
        $type = $request->input('type', 'available');

        if ($type === 'available') {
            if (! $driver->driverProfile?->canReceiveRequests()) {
                return $this->ok([], 'Go online (and be verified) to see delivery requests.');
            }
            $query = $this->deliveries->availableFor($driver);
        } else {
            $statuses = match ($type) {
                'active' => DeliveryStatus::active(),
                'completed' => [DeliveryStatus::Delivered],
                'cancelled' => [DeliveryStatus::Cancelled],
                default => [DeliveryStatus::Delivered, DeliveryStatus::Cancelled],
            };
            $query = Delivery::where('driver_id', $driver->id)->whereIn('status', $statuses)
                ->when($request->date_from, fn ($q, $d) => $q->whereDate('created_at', '>=', $d))
                ->when($request->date_to, fn ($q, $d) => $q->whereDate('created_at', '<=', $d))
                ->latest('updated_at');
        }

        return $this->ok(DeliveryResource::collection($query->with(self::WITH)->paginate($this->perPage(20))));
    }

    public function show(Delivery $delivery): JsonResponse
    {
        $this->authorize('view', $delivery);

        return $this->ok(new DeliveryResource($delivery->load(self::WITH)));
    }

    /** POST /api/driver/deliveries/{id}/accept */
    public function accept(Request $request, Delivery $delivery): JsonResponse
    {
        $this->authorize('view', $delivery);
        $delivery = $this->deliveries->accept($delivery, $request->user());

        return $this->ok(new DeliveryResource($delivery->load(self::WITH)), 'Delivery accepted. Head to the store.');
    }

    /** POST /api/driver/deliveries/{id}/reject — hide this request from me. */
    public function reject(Request $request, Delivery $delivery): JsonResponse
    {
        $this->authorize('view', $delivery);
        $this->deliveries->decline($delivery, $request->user());

        return $this->ok(null, 'Request dismissed.');
    }

    /** POST /api/driver/deliveries/{id}/release — give back before pickup. */
    public function release(Request $request, Delivery $delivery): JsonResponse
    {
        $this->authorize('update', $delivery);
        $request->validate(['reason' => ['nullable', 'string', 'max:255']]);
        $this->deliveries->release($delivery, $request->user(), $request->reason);

        return $this->ok(null, 'Delivery released to other drivers.');
    }

    /** PATCH /api/driver/deliveries/{id}/status {status: picked_up|arriving|delivered, note?} */
    public function updateStatus(Request $request, Delivery $delivery): JsonResponse
    {
        $this->authorize('update', $delivery);
        $data = $request->validate([
            'status' => ['required', Rule::in(['picked_up', 'arriving', 'delivered'])],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $delivery = $this->deliveries->updateStatus($delivery, $request->user(), DeliveryStatus::from($data['status']), $data['note'] ?? null);
        $messages = ['picked_up' => 'Pickup confirmed. Head to the classroom.', 'arriving' => 'Customer notified that you are arriving.', 'delivered' => 'Delivery completed. Great job!'];

        return $this->ok(new DeliveryResource($delivery->load(self::WITH)), $messages[$data['status']]);
    }
}
