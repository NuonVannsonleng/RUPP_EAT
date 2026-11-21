<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\AppNotification;
use App\Models\Order;
use App\Models\User;

/** Stores in-app notifications and forwards them as push notifications. */
class NotificationService
{
    public function __construct(private PushNotificationService $push) {}

    public function notify(User|string $user, string $type, string $title, string $body, array $data = []): AppNotification
    {
        $user = $user instanceof User ? $user : User::findOrFail($user);

        $notification = AppNotification::create([
            'user_id' => $user->id,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'data' => $data,
        ]);

        $this->push->send($user->fcm_token, $title, $body, $data + ['type' => $type, 'notification_id' => $notification->id]);

        return $notification;
    }

    /** Customer-facing message for each order status. */
    public function orderStatusChanged(Order $order): void
    {
        $no = $order->order_number;
        $store = $order->store->name;
        $data = ['order_id' => $order->id, 'order_number' => $no, 'status' => $order->status->value];

        [$type, $title, $body] = match ($order->status) {
            OrderStatus::Accepted => ['order_accepted', 'Order accepted', "$store accepted your order $no."],
            OrderStatus::Preparing => ['order_preparing', 'Preparing your food', "$store started preparing order $no."],
            OrderStatus::Ready => $order->isPickup()
                ? ['order_ready', 'Ready for pickup', "Order $no is ready. Show pickup code {$order->pickup_code} at $store."]
                : ['order_ready', 'Food is ready', "Order $no is ready and waiting for a driver."],
            OrderStatus::DriverAssigned => ['driver_assigned', 'Driver assigned', ($order->driver?->name ?? 'A driver')." will deliver order $no."],
            OrderStatus::OnTheWay => ['order_on_the_way', 'On the way', "Your order $no has been picked up and is on the way to your classroom."],
            OrderStatus::Delivered => ['order_completed', 'Order delivered', "Order $no was delivered. Enjoy your meal!"],
            OrderStatus::PickedUp => ['order_completed', 'Order picked up', "Order $no was picked up. Enjoy your meal!"],
            OrderStatus::Rejected => ['order_rejected', 'Order rejected', "$store could not accept order $no".($order->cancel_reason ? ": {$order->cancel_reason}" : '.')],
            OrderStatus::Cancelled => ['order_cancelled', 'Order cancelled', "Order $no was cancelled".($order->cancel_reason ? ": {$order->cancel_reason}" : '.')],
            default => [null, null, null],
        };

        if ($type) {
            $this->notify($order->customer_id, $type, $title, $body, $data);
        }
    }

    public function driverApproaching(Order $order): void
    {
        $this->notify($order->customer_id, 'driver_approaching', 'Driver approaching',
            "Your driver is arriving at {$this->destination($order)} with order {$order->order_number}.",
            ['order_id' => $order->id, 'order_number' => $order->order_number, 'status' => $order->status->value]);
    }

    /** Tell the store's owner + staff about a new order. */
    public function newOrderForStore(Order $order): void
    {
        $recipients = $order->store->staff()->pluck('users.id')->push($order->store->owner_id)->unique();
        foreach ($recipients as $userId) {
            $this->notify($userId, 'new_order', 'New order received',
                "Order {$order->order_number} (".'$'.number_format((float) $order->total, 2).') is waiting for confirmation.',
                ['order_id' => $order->id, 'order_number' => $order->order_number]);
        }
    }

    private function destination(Order $order): string
    {
        $loc = $order->delivery_location ?? [];

        return trim(($loc['building'] ?? '').' '.($loc['room'] ?? '')) ?: 'your location';
    }
}
