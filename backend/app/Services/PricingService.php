<?php

namespace App\Services;

use App\Enums\FulfillmentMethod;
use App\Models\SystemSetting;

/** All money is computed on the server from database prices. Clients never send prices. */
class PricingService
{
    public function deliveryFee(float $subtotal, FulfillmentMethod $method): float
    {
        if ($method === FulfillmentMethod::Pickup) {
            return 0.0;
        }

        $threshold = (float) SystemSetting::get('free_delivery_threshold', 0);
        if ($threshold > 0 && $subtotal >= $threshold) {
            return 0.0;
        }

        return round((float) SystemSetting::get('delivery_fee', 0.5), 2);
    }

    public function minimumOrder(): float
    {
        return (float) SystemSetting::get('min_order_amount', 0);
    }
}
