<?php

namespace App\Policies;

use App\Models\Store;
use App\Models\User;

class StorePolicy
{
    public function create(User $user): bool
    {
        return $user->isAdmin();
    }

    /** Owners/staff edit their own store profile; admins edit any store. */
    public function update(User $user, Store $store): bool
    {
        return $user->canManageStore($store);
    }

    public function delete(User $user, Store $store): bool
    {
        return $user->isAdmin();
    }
}
