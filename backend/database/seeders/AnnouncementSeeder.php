<?php

namespace Database\Seeders;

use App\Models\Announcement;
use App\Models\Store;
use App\Models\User;
use Illuminate\Database\Seeder;

class AnnouncementSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::where('email', 'admin@rupp.edu.kh')->value('id');

        $items = [
            ['Welcome to RUPP Eat!', 'Order from campus stores and get food delivered straight to your classroom, or skip the queue with self-pickup.', 'announcement', 'all', null, '1414235077428-338989a2e8c0'],
            ['Free delivery over $10', 'Orders of $10 or more get free classroom delivery anywhere on campus.', 'promotion', 'customers', null, '1504674900247-0877df9cc836'],
            ['Morning coffee deal', 'Campus Café: any coffee + Egg & Cheese Toast before 9 AM. Fuel up for your first class!', 'promotion', 'customers', 'campus-cafe', '1495474472287-4d71bcdd2085'],
            ['Driver reminder', 'Please confirm pickup in the app before leaving the store, and use the classroom details to find the customer.', 'announcement', 'drivers', null, null],
        ];

        foreach ($items as [$title, $body, $type, $audience, $storeSlug, $img]) {
            Announcement::updateOrCreate(['title' => $title], [
                'body' => $body,
                'type' => $type,
                'audience' => $audience,
                'store_id' => $storeSlug ? Store::where('slug', $storeSlug)->value('id') : null,
                'image_path' => $img ? "https://images.unsplash.com/photo-$img?w=1000&q=70&auto=format&fit=crop" : null,
                'is_active' => true,
                'created_by' => $admin,
            ]);
        }
    }
}
