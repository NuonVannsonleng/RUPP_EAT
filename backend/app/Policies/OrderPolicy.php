<?php

namespace App\Policies;

use App\Models\Order;
use App\Models\User;

class OrderPolicy
{
    /** Customer who placed it, the assigned driver, the store's owner/staff, or an admin. */
    public function view(User $user, Order $order): bool
    {
        return $user->isAdmin()
            || $order->customer_id === $user->id
            || ($order->driver_id !== null && $order->driver_id === $user->id)
            || $user->canManageStore($order->store_id);
    }

    /** Status changes from the store dashboard. */
    public function manage(User $user, Order $order): bool
    {
        return $user->isAdmin() || ($user->hasRole('store_owner') && $user->canManageStore($order->store_id));
    }

    public function cancel(User $user, Order $order): bool
    {
        return $order->customer_id === $user->id;
    }
}
