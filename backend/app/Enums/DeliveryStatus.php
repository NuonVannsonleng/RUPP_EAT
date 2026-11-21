<?php

namespace App\Enums;

enum DeliveryStatus: string
{
    case Pending = 'pending';       // order not yet released to drivers
    case Searching = 'searching';   // visible to online drivers
    case Assigned = 'assigned';
    case PickedUp = 'picked_up';
    case Arriving = 'arriving';
    case Delivered = 'delivered';
    case Cancelled = 'cancelled';

    public static function active(): array
    {
        return [self::Assigned, self::PickedUp, self::Arriving];
    }
}
