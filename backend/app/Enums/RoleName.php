<?php

namespace App\Enums;

enum RoleName: string
{
    case Customer = 'customer';
    case Driver = 'driver';
    case StoreOwner = 'store_owner';
    case Admin = 'admin';
}
