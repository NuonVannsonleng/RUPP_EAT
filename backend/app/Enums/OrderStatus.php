<?php

namespace App\Enums;

enum OrderStatus: string
{
    case Pending = 'pending';
    case Accepted = 'accepted';
    case Preparing = 'preparing';
    case Ready = 'ready';
    case DriverAssigned = 'driver_assigned';
    case OnTheWay = 'on_the_way';
    case Delivered = 'delivered';
    case PickedUp = 'picked_up';
    case Rejected = 'rejected';
    case Cancelled = 'cancelled';

    /** Statuses after which nothing can change. */
    public function isFinal(): bool
    {
        return in_array($this, [self::Delivered, self::PickedUp, self::Rejected, self::Cancelled], true);
    }

    public function isCompleted(): bool
    {
        return in_array($this, [self::Delivered, self::PickedUp], true);
    }

    public static function active(): array
    {
        return [self::Pending, self::Accepted, self::Preparing, self::Ready, self::DriverAssigned, self::OnTheWay];
    }

    public static function completed(): array
    {
        return [self::Delivered, self::PickedUp];
    }

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Pending confirmation',
            self::Accepted => 'Accepted',
            self::Preparing => 'Preparing',
            self::Ready => 'Ready',
            self::DriverAssigned => 'Driver assigned',
            self::OnTheWay => 'On the way',
            self::Delivered => 'Delivered',
            self::PickedUp => 'Picked up',
            self::Rejected => 'Rejected',
            self::Cancelled => 'Cancelled',
        };
    }
}
