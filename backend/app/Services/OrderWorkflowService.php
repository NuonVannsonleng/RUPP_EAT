<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Events\OrderStatusChanged;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The order state machine. Every status change goes through transition() so that
 * timestamps, stock, payments, deliveries, logs and notifications stay consistent.
 *
 *   pending ──accept──> accepted ──> preparing ──> ready ──(pickup: store verifies code)──> picked_up
 *      │                    │            │           └─(delivery)─> driver_assigned ─> on_the_way ─> delivered
 *      ├─reject─> rejected  └────────────┴──cancel──> cancelled
 *      └─customer cancel─> cancelled
 */
class OrderWorkflowService
{
    /** Transitions a store (owner/staff) may perform. */
    private const STORE_TRANSITIONS = [
        'pending' => ['accepted', 'rejected'],
        'accepted' => ['preparing', 'cancelled'],
        'preparing' => ['ready', 'cancelled'],
        'ready' => ['picked_up', 'cancelled'],
    ];

    public function __construct(
        private NotificationService $notifications,
        private DeliveryService $deliveries,
    ) {}

    /** Store / admin initiated change from the dashboard. */
    public function updateByStore(Order $order, OrderStatus $to, User $actor, array $input = []): Order
    {
        $from = $order->status->value;
        $allowed = self::STORE_TRANSITIONS[$from] ?? [];

        if ($actor->isAdmin() && $to === OrderStatus::Cancelled && ! $order->status->isFinal()) {
            $allowed[] = 'cancelled'; // admins can cancel at any active stage (dispute resolution)
        }

        if (! in_array($to->value, $allowed, true)) {
            throw ValidationException::withMessages(['status' => "Cannot change an order from \"{$order->status->label()}\" to \"{$to->label()}\"."]);
        }

        if ($to === OrderStatus::PickedUp) {
            if (! $order->isPickup()) {
                throw ValidationException::withMessages(['status' => 'Delivery orders are completed by the driver.']);
            }
            if (($input['pickup_code'] ?? null) !== $order->pickup_code) {
                throw ValidationException::withMessages(['pickup_code' => 'The pickup code does not match this order.']);
            }
        }

        if (in_array($to, [OrderStatus::Rejected, OrderStatus::Cancelled], true) && empty($input['reason'])) {
            throw ValidationException::withMessages(['reason' => 'Please give a reason.']);
        }

        return $this->transition($order, $to, $actor, $input['reason'] ?? $input['note'] ?? null);
    }

    /** Customers may cancel only while the store has not accepted yet. */
    public function cancelByCustomer(Order $order, User $customer, ?string $reason): Order
    {
        if ($order->status !== OrderStatus::Pending) {
            throw ValidationException::withMessages(['status' => 'This order was already accepted by the store and can no longer be cancelled. Please contact support.']);
        }

        return $this->transition($order, OrderStatus::Cancelled, $customer, $reason ?: 'Cancelled by customer');
    }

    /** Core transition with all side effects, inside one DB transaction. */
    public function transition(Order $order, OrderStatus $to, ?User $actor, ?string $note = null): Order
    {
        $from = $order->status;

        DB::transaction(function () use ($order, $to, $actor, $note, $from) {
            $order->refresh();
            if ($order->status !== $from) {
                throw ValidationException::withMessages(['status' => 'This order was updated by someone else. Please refresh.']);
            }

            $order->status = $to;
            match ($to) {
                OrderStatus::Accepted => $order->accepted_at = now(),
                OrderStatus::Ready => $order->ready_at = now(),
                OrderStatus::Delivered, OrderStatus::PickedUp => $this->complete($order, $actor),
                OrderStatus::Rejected, OrderStatus::Cancelled => $this->cancel($order, $actor, $note),
                default => null,
            };
            $order->save();

            $order->statusLogs()->create([
                'from_status' => $from->value,
                'to_status' => $to->value,
                'changed_by' => $actor?->id,
                'note' => $note,
            ]);
        });

        $order->load(['store', 'driver', 'delivery']);
        $this->notifications->orderStatusChanged($order);
        event(new OrderStatusChanged($order, $from->value, $to->value));
        ActivityLogger::log('order.'.$to->value, "Order {$order->order_number}: {$from->label()} → {$to->label()}", $order);

        // Delivery orders: release to drivers when food is ready (if the store did not already).
        if ($to === OrderStatus::Ready && $order->isDelivery()) {
            if ($order->delivery->status === DeliveryStatus::Pending) {
                $this->deliveries->request($order, $actor);
            } elseif ($order->delivery->status === DeliveryStatus::Assigned) {
                $this->transition($order, OrderStatus::DriverAssigned, $actor, 'Driver already assigned');
            }
        }

        return $order->fresh(['items', 'store', 'driver', 'delivery', 'statusLogs']);
    }

    private function complete(Order $order, ?User $actor): void
    {
        $order->completed_at = now();
        $order->payment_status = PaymentStatus::Paid;

        // Cash is collected in person; the person completing the hand-over confirms it.
        $order->payments()->where('status', PaymentStatus::Pending)->update([
            'status' => PaymentStatus::Paid,
            'paid_at' => now(),
            'collected_by' => $actor?->id,
        ]);

        foreach ($order->items as $item) {
            if ($item->product_id) {
                Product::withTrashed()->whereKey($item->product_id)->increment('sold_count', $item->quantity);
            }
        }
    }

    private function cancel(Order $order, ?User $actor, ?string $reason): void
    {
        $order->cancelled_at = now();
        $order->cancelled_by = $actor?->id;
        $order->cancel_reason = $reason;
        $order->payment_status = $order->payment_status === PaymentStatus::Paid ? PaymentStatus::Refunded : PaymentStatus::Cancelled;
        $order->payments()->where('status', PaymentStatus::Pending)->update(['status' => PaymentStatus::Cancelled]);

        // Return reserved stock.
        foreach ($order->items as $item) {
            $product = $item->product_id ? Product::withTrashed()->lockForUpdate()->find($item->product_id) : null;
            if ($product && $product->stock_quantity !== null) {
                $product->increment('stock_quantity', $item->quantity);
            }
        }

        if ($delivery = $order->delivery) {
            $delivery->update(['status' => DeliveryStatus::Cancelled, 'cancelled_at' => now()]);
            $delivery->statusLogs()->create(['status' => 'cancelled', 'changed_by' => $actor?->id, 'note' => $reason]);
        }
    }
}
