<?php

namespace App\Enums;

enum PaymentMethod: string
{
    case CashOnDelivery = 'cash_on_delivery';
    case CashOnPickup = 'cash_on_pickup';
    case Khqr = 'khqr';

    public function isCash(): bool
    {
        return $this !== self::Khqr;
    }

    public function label(): string
    {
        return match ($this) {
            self::CashOnDelivery => 'Cash on delivery',
            self::CashOnPickup => 'Cash on pickup',
            self::Khqr => 'Bakong KHQR',
        };
    }
}
