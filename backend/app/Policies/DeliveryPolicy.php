<?php

namespace App\Policies;

use App\Enums\DeliveryStatus;
use App\Models\Delivery;
use App\Models\User;

class DeliveryPolicy
{
    /**
     * A driver may see a delivery only if it is assigned to them, or it is an open
     * request (searching) they could accept.
     */
    public function view(User $user, Delivery $delivery): bool
    {
        if ($user->isAdmin()) {
            return true;
        }

        return $user->hasRole('driver') && (
            $delivery->driver_id === $user->id
            || ($delivery->driver_id === null && $delivery->status === DeliveryStatus::Searching)
        );
    }

    public function update(User $user, Delivery $delivery): bool
    {
        return $user->hasRole('driver') && $delivery->driver_id === $user->id;
    }
}
