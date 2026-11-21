<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Enums\RoleName;
use App\Http\Controllers\Controller;
use App\Http\Requests\PlaceOrderRequest;
use App\Http\Requests\UpdateOrderStatusRequest;
use App\Http\Resources\CartResource;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\CartService;
use App\Services\DeliveryService;
use App\Services\OrderService;
use App\Services\OrderWorkflowService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class OrderController extends Controller
{
    public function __construct(
        private OrderService $orders,
        private OrderWorkflowService $workflow,
    ) {}

    /**
     * GET /api/orders — scoped by role:
     * customer = own orders, driver = assigned, store owner = own stores, admin = all.
     * Filters: status (comma list | active | completed | cancelled), store_id, fulfillment_method,
     *          date_from, date_to, search (order number / customer name).
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $query = Order::query()->with(['store.building', 'items.product', 'customer', 'driver', 'delivery']);
        match (true) {
            $user->isAdmin() => null,
            $user->hasRole(RoleName::StoreOwner) => $query->whereIn('store_id', $user->managedStoreIds()),
            $user->hasRole(RoleName::Driver) => $query->where('driver_id', $user->id),
            default => $query->where('customer_id', $user->id),
        };

        $orders = $this->applyFilters($query, $request)->latest()->paginate($this->perPage());

        return $this->ok(OrderResource::collection($orders));
    }

    public function show(Order $order): JsonResponse
    {
        $this->authorize('view', $order);

        return $this->ok(new OrderResource($order->load([
            'items.product', 'store.building', 'customer', 'driver', 'delivery', 'statusLogs', 'reviews',
        ])));
    }

    /** POST /api/orders — place an order from the cart. Header: Idempotency-Key. */
    public function store(PlaceOrderRequest $request): JsonResponse
    {
        $key = $request->header('Idempotency-Key');
        if ($key !== null && ! preg_match('/^[A-Za-z0-9\-]{8,64}$/', $key)) {
            throw ValidationException::withMessages(['idempotency_key' => 'Invalid Idempotency-Key header.']);
        }

        [$order, $created] = $this->orders->place($request->user(), $request->validated(), $key);
        $resource = new OrderResource($order->load(['items.product', 'store.building', 'delivery', 'statusLogs']));

        return $created
            ? $this->created($resource, 'Order placed! Waiting for the store to confirm.')
            : $this->ok($resource, 'This order was already placed.');
    }

    /** PATCH /api/orders/{id}/status — store/admin workflow, or customer cancellation. */
    public function updateStatus(UpdateOrderStatusRequest $request, Order $order): JsonResponse
    {
        $user = $request->user();
        $to = OrderStatus::from($request->status);

        if ($user->id === $order->customer_id && ! $user->canManageStore($order->store_id)) {
            if ($to !== OrderStatus::Cancelled) {
                abort(403, 'Customers can only cancel their own pending orders.');
            }
            $order = $this->workflow->cancelByCustomer($order, $user, $request->reason);

            return $this->ok(new OrderResource($order->load('customer')), 'Order cancelled.');
        }

        $this->authorize('manage', $order);
        $order = $this->workflow->updateByStore($order, $to, $user, $request->validated());

        return $this->ok(new OrderResource($order->load(['customer', 'items.product'])), "Order is now {$order->status->label()}.");
    }

    /** POST /api/orders/{id}/request-driver — store releases a delivery order to drivers. */
    public function requestDriver(Request $request, Order $order, DeliveryService $deliveries): JsonResponse
    {
        $this->authorize('manage', $order);
        $deliveries->request($order->load('delivery'), $request->user());

        return $this->ok(new OrderResource($order->fresh(['delivery', 'driver', 'customer', 'items.product', 'store'])), 'Looking for a driver.');
    }

    /** POST /api/orders/{id}/reorder — put the same items back into the cart. */
    public function reorder(Request $request, Order $order, CartService $cart): JsonResponse
    {
        abort_unless($order->customer_id === $request->user()->id, 404);

        $cart->clear($request->user());
        $skipped = [];
        foreach ($order->items()->with('product')->get() as $item) {
            if (! $item->product || ! $item->product->canFulfil($item->quantity)) {
                $skipped[] = $item->product_name;

                continue;
            }
            $cart->add($request->user(), $item->product_id, $item->quantity, $item->note, true);
        }

        $message = $skipped
            ? 'Some items are no longer available: '.implode(', ', $skipped).'.'
            : 'Items added to your cart.';

        return $this->ok([
            'cart' => (new CartResource($cart->cartFor($request->user())))->resolve($request),
            'skipped' => $skipped,
        ], $message);
    }

    private function applyFilters(Builder $query, Request $request): Builder
    {
        return $query
            ->when($request->status, function ($q, $status) {
                return match ($status) {
                    'active' => $q->whereIn('status', array_map(fn ($s) => $s->value, OrderStatus::active())),
                    'completed' => $q->whereIn('status', ['delivered', 'picked_up']),
                    'cancelled' => $q->whereIn('status', ['cancelled', 'rejected']),
                    default => $q->whereIn('status', explode(',', $status)),
                };
            })
            ->when($request->store_id, fn ($q, $id) => $q->where('store_id', $id))
            ->when($request->customer_id, fn ($q, $id) => $q->where('customer_id', $id))
            ->when($request->driver_id, fn ($q, $id) => $q->where('driver_id', $id))
            ->when($request->fulfillment_method, fn ($q, $m) => $q->where('fulfillment_method', $m))
            ->when($request->date_from, fn ($q, $d) => $q->whereDate('created_at', '>=', $d))
            ->when($request->date_to, fn ($q, $d) => $q->whereDate('created_at', '<=', $d))
            ->when($request->search, fn ($q, $s) => $q->where(fn ($w) => $w
                ->where('order_number', 'ilike', "%$s%")
                ->orWhereHas('customer', fn ($c) => $c->where('name', 'ilike', "%$s%")->orWhere('university_id', 'ilike', "%$s%"))));
    }
}
