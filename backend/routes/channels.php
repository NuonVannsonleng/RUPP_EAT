<?php

use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

/*
 | Private broadcast channels. Clients subscribe after authenticating with Sanctum.
 | BROADCAST_CONNECTION=log by default; switch to reverb/pusher for live websockets.
 */

Broadcast::channel('users.{userId}', fn (User $user, string $userId) => $user->id === $userId);

Broadcast::channel('stores.{storeId}', fn (User $user, string $storeId) => $user->canManageStore($storeId));

Broadcast::channel('orders.{orderId}', function (User $user, string $orderId) {
    $order = Order::find($orderId);

    return $order && ($user->isAdmin()
        || $order->customer_id === $user->id
        || $order->driver_id === $user->id
        || $user->canManageStore($order->store_id));
});

Broadcast::channel('drivers', fn (User $user) => $user->hasRole('driver')
    && $user->driverProfile?->canReceiveRequests());
