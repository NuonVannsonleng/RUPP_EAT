<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\OrderStatus;
use App\Events\DeliveryRequested;
use App\Models\Delivery;
use App\Models\Order;
use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

/**
 * Campus delivery lifecycle:
 *   pending ─(store requests / order ready)─> searching ─(driver accepts)─> assigned
 *   ─(driver confirms pickup)─> picked_up ─(optional "arriving")─> arriving ─> delivered
 */
class DeliveryService
{
    public function __construct(private NotificationService $notifications) {}

    /** Release a delivery order to online drivers. */
    public function request(Order $order, ?User $actor): Delivery
    {
        $delivery = $order->delivery;

        if (! $order->isDelivery() || ! $delivery) {
            throw ValidationException::withMessages(['order' => 'This is a pickup order and does not need a driver.']);
        }
        if (! in_array($order->status, [OrderStatus::Accepted, OrderStatus::Preparing, OrderStatus::Ready], true)) {
            throw ValidationException::withMessages(['order' => 'Accept the order before requesting a driver.']);
        }
        if ($delivery->status !== DeliveryStatus::Pending) {
            throw ValidationException::withMessages(['order' => 'A driver has already been requested for this order.']);
        }

        $delivery->update(['status' => DeliveryStatus::Searching, 'requested_at' => now()]);
        $delivery->statusLogs()->create(['status' => 'searching', 'changed_by' => $actor?->id, 'note' => 'Driver requested']);

        event(new DeliveryRequested($delivery));
        $this->notifyOnlineDrivers($order);

        return $delivery;
    }

    /** Requests visible to a driver: searching, not declined by them. */
    public function availableFor(User $driver): Builder
    {
        return Delivery::query()
            ->where('status', DeliveryStatus::Searching)
            ->whereNull('driver_id')
            ->whereDoesntHave('order', fn ($q) => $q->whereIn('status', ['cancelled', 'rejected']))
            ->whereNotExists(fn ($q) => $q->select(DB::raw(1))
                ->from('delivery_declines')
                ->whereColumn('delivery_declines.delivery_id', 'deliveries.id')
                ->where('delivery_declines.driver_id', $driver->id))
            ->orderBy('requested_at');
    }

    public function accept(Delivery $delivery, User $driver): Delivery
    {
        $profile = $driver->driverProfile;
        if (! $profile?->isVerified() || ! $profile->is_active) {
            throw ValidationException::withMessages(['driver' => 'Your driver account must be verified by an administrator first.']);
        }
        if (! $profile->is_online) {
            throw ValidationException::withMessages(['driver' => 'Go online to accept deliveries.']);
        }

        $max = (int) SystemSetting::get('max_active_deliveries_per_driver', 2);
        $active = Delivery::where('driver_id', $driver->id)->whereIn('status', DeliveryStatus::active())->count();
        if ($active >= $max) {
            throw ValidationException::withMessages(['driver' => "You can carry at most $max deliveries at a time."]);
        }

        $order = DB::transaction(function () use ($delivery, $driver) {
            // Row lock: two drivers tapping "Accept" at once -> only the first wins.
            $locked = Delivery::whereKey($delivery->id)->lockForUpdate()->firstOrFail();
            if ($locked->status !== DeliveryStatus::Searching || $locked->driver_id) {
                throw new ConflictHttpException('Another driver already accepted this delivery.');
            }

            $locked->update(['driver_id' => $driver->id, 'status' => DeliveryStatus::Assigned, 'assigned_at' => now()]);
            $locked->statusLogs()->create(['status' => 'assigned', 'changed_by' => $driver->id]);

            $order = $locked->order;
            $order->update(['driver_id' => $driver->id]);

            return $order;
        });

        ActivityLogger::log('delivery.accepted', "{$driver->name} accepted order {$order->order_number}", $delivery);

        if ($order->status === OrderStatus::Ready) {
            app(OrderWorkflowService::class)->transition($order, OrderStatus::DriverAssigned, $driver);
        } else {
            // Food still being prepared: let the customer know who is coming.
            $this->notifications->notify($order->customer_id, 'driver_assigned', 'Driver assigned',
                "{$driver->name} will deliver order {$order->order_number} once it is ready.",
                ['order_id' => $order->id, 'order_number' => $order->order_number, 'status' => $order->status->value]);
        }

        return $delivery->fresh(['order', 'driver']);
    }

    public function decline(Delivery $delivery, User $driver): void
    {
        DB::table('delivery_declines')->insertOrIgnore([
            'id' => (string) \Illuminate\Support\Str::uuid(),
            'delivery_id' => $delivery->id,
            'driver_id' => $driver->id,
            'created_at' => now(),
        ]);
    }

    /** Driver progress updates on an assigned delivery. */
    public function updateStatus(Delivery $delivery, User $driver, DeliveryStatus $to, ?string $note = null): Delivery
    {
        if ($delivery->driver_id !== $driver->id) {
            abort(403, 'This delivery is not assigned to you.');
        }

        $order = $delivery->order;
        $workflow = app(OrderWorkflowService::class);

        switch ($to) {
            case DeliveryStatus::PickedUp:
                if ($delivery->status !== DeliveryStatus::Assigned) {
                    throw ValidationException::withMessages(['status' => 'Pickup can only be confirmed once.']);
                }
                if (! in_array($order->status, [OrderStatus::Ready, OrderStatus::DriverAssigned], true)) {
                    throw ValidationException::withMessages(['status' => 'The store has not marked this order as ready yet.']);
                }
                $this->setStatus($delivery, $to, $driver, $note, ['picked_up_at' => now()]);
                if ($order->status === OrderStatus::Ready) {
                    $order = $workflow->transition($order, OrderStatus::DriverAssigned, $driver);
                }
                $workflow->transition($order, OrderStatus::OnTheWay, $driver, 'Food picked up by driver');
                break;

            case DeliveryStatus::Arriving:
                if ($delivery->status !== DeliveryStatus::PickedUp) {
                    throw ValidationException::withMessages(['status' => 'Confirm pickup before arriving.']);
                }
                $this->setStatus($delivery, $to, $driver, $note);
                $this->notifications->driverApproaching($order);
                break;

            case DeliveryStatus::Delivered:
                if (! in_array($delivery->status, [DeliveryStatus::PickedUp, DeliveryStatus::Arriving], true)) {
                    throw ValidationException::withMessages(['status' => 'Confirm pickup before completing delivery.']);
                }
                $this->setStatus($delivery, $to, $driver, $note, ['delivered_at' => now()]);
                $workflow->transition($order, OrderStatus::Delivered, $driver, 'Delivered to customer');
                break;

            default:
                throw ValidationException::withMessages(['status' => 'Unsupported delivery status.']);
        }

        return $delivery->fresh(['order', 'driver']);
    }

    /** Driver gives back an accepted delivery before picking it up. */
    public function release(Delivery $delivery, User $driver, ?string $reason): Delivery
    {
        if ($delivery->driver_id !== $driver->id || $delivery->status !== DeliveryStatus::Assigned) {
            throw ValidationException::withMessages(['status' => 'Only an assigned delivery that is not yet picked up can be released.']);
        }

        DB::transaction(function () use ($delivery, $driver, $reason) {
            $delivery->update(['driver_id' => null, 'status' => DeliveryStatus::Searching, 'assigned_at' => null]);
            $delivery->statusLogs()->create(['status' => 'released', 'changed_by' => $driver->id, 'note' => $reason]);
            $delivery->order->update(['driver_id' => null]);
            if ($delivery->order->status === OrderStatus::DriverAssigned) {
                $delivery->order->update(['status' => OrderStatus::Ready]);
                $delivery->order->statusLogs()->create([
                    'from_status' => 'driver_assigned', 'to_status' => 'ready', 'changed_by' => $driver->id, 'note' => 'Driver released the delivery',
                ]);
            }
            $this->decline($delivery, $driver);
        });

        event(new DeliveryRequested($delivery));

        return $delivery->fresh();
    }

    private function setStatus(Delivery $delivery, DeliveryStatus $to, User $actor, ?string $note, array $extra = []): void
    {
        $delivery->update(['status' => $to] + $extra);
        $delivery->statusLogs()->create(['status' => $to->value, 'changed_by' => $actor->id, 'note' => $note]);
    }

    private function notifyOnlineDrivers(Order $order): void
    {
        $order->loadMissing('store');
        $drivers = User::whereHas('driverProfile', fn ($q) => $q
            ->where('verification_status', 'verified')->where('is_active', true)->where('is_online', true))
            ->where('status', 'active')
            ->get();

        $dest = $order->delivery_location;
        foreach ($drivers as $driver) {
            $this->notifications->notify($driver, 'delivery_request', 'New delivery request',
                "{$order->store->name} → ".($dest['building'] ?? 'campus').' '.($dest['room'] ?? '').' · $'.number_format((float) $order->delivery_fee, 2).' fee',
                ['order_id' => $order->id, 'delivery_id' => $order->delivery->id]);
        }
    }
}
