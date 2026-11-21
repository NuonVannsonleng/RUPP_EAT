<?php

namespace Database\Seeders;

use App\Models\SystemSetting;
use Illuminate\Database\Seeder;

class SettingSeeder extends Seeder
{
    public function run(): void
    {
        $settings = [
            ['key' => 'delivery_fee', 'value' => '0.50', 'type' => 'number', 'group' => 'delivery', 'description' => 'Classroom delivery fee (USD).'],
            ['key' => 'free_delivery_threshold', 'value' => '10', 'type' => 'number', 'group' => 'delivery', 'description' => 'Free delivery when the subtotal reaches this amount (0 = never).'],
            ['key' => 'delivery_enabled', 'value' => 'true', 'type' => 'boolean', 'group' => 'delivery', 'description' => 'Allow classroom delivery orders.'],
            ['key' => 'max_active_deliveries_per_driver', 'value' => '2', 'type' => 'number', 'group' => 'delivery', 'description' => 'How many deliveries one driver may carry at once.'],
            ['key' => 'min_order_amount', 'value' => '0.50', 'type' => 'number', 'group' => 'orders', 'description' => 'Minimum food subtotal per order (USD).'],
            ['key' => 'support_phone', 'value' => '+855 23 883 640', 'type' => 'string', 'group' => 'general', 'description' => 'Support phone shown in the apps.'],
            ['key' => 'support_email', 'value' => 'support@rupp-eat.edu.kh', 'type' => 'string', 'group' => 'general', 'description' => 'Support email shown in the apps.'],
        ];

        foreach ($settings as $s) {
            SystemSetting::updateOrCreate(['key' => $s['key']], $s);
        }
    }
}
