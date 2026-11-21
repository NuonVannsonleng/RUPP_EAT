<?php

namespace Database\Seeders;

use App\Models\Building;
use App\Models\ProductCategory;
use App\Models\Store;
use App\Models\StoreApplication;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

/** Five sample campus stores with menus. Images are Unsplash photos (internet required to display). */
class StoreSeeder extends Seeder
{
    private function img(string $id, int $w = 800): string
    {
        return "https://images.unsplash.com/photo-$id?w=$w&q=70&auto=format&fit=crop";
    }

    public function run(): void
    {
        $cat = ProductCategory::pluck('id', 'slug');
        $building = Building::pluck('id', 'code');
        $owner = User::pluck('id', 'email');

        $stores = [
            [
                'owner' => 'owner.cafe@rupp.edu.kh', 'name' => 'Campus Café', 'building' => 'LIB',
                'location' => 'Ground floor, next to the library entrance', 'phone' => '012 555 001',
                'hours' => ['00:00', '23:59'], 'featured' => true, 'cover' => '1509042239860-f550ce710b93',
                'description' => 'Fresh coffee, Khmer iced coffee and quick breakfasts for early classes.',
                'products' => [
                    ['Iced Khmer Coffee', 'coffee', 1.25, '1461023058943-07fcbe16d735', 'Strong Cambodian coffee with sweet condensed milk over ice.', null],
                    ['Iced Latte', 'coffee', 1.50, '1517701604599-bb29b565090c', 'Espresso, fresh milk and ice.', null],
                    ['Hot Latte', 'coffee', 1.50, '1541167760496-1628856ab772', 'Smooth espresso with steamed milk.', null],
                    ['Cappuccino', 'coffee', 1.75, '1495474472287-4d71bcdd2085', 'Espresso with thick milk foam.', null],
                    ['Egg & Cheese Toast', 'breakfast', 1.75, '1525351484163-7529414344d8', 'Sourdough toast with fried egg and cheddar.', 25],
                    ['Avocado Egg Toast', 'breakfast', 2.50, '1482049016688-2d3e1b311543', 'Smashed avocado, boiled egg, chili flakes.', 15],
                    ['Blueberry French Toast', 'breakfast', 2.25, '1484723091739-30a097e8f929', 'Thick French toast with banana and blueberries.', 12],
                    ['Sprinkle Donut', 'snacks', 0.75, '1551024601-bec78aea704b', 'Chocolate glazed donut with sprinkles.', 30],
                ],
            ],
            [
                'owner' => 'owner.khmer@rupp.edu.kh', 'name' => 'Khmer Kitchen', 'building' => 'SC',
                'location' => 'Student Center food court, stall 3', 'phone' => '012 555 002',
                'hours' => ['06:30', '20:00'], 'featured' => true, 'cover' => '1555939594-58d7cb561ad1',
                'description' => 'Home-style Cambodian rice dishes cooked fresh every morning.',
                'products' => [
                    ['Bai Sach Chrouk', 'rice-dishes', 1.75, '1555939594-58d7cb561ad1', 'Grilled marinated pork over broken rice with pickles and broth.', null],
                    ['Bai Cha (Khmer Fried Rice)', 'rice-dishes', 1.50, '1603133872878-684f208fb84b', 'Fried rice with egg, Chinese sausage and vegetables.', null],
                    ['Chicken Curry with Rice', 'rice-dishes', 2.00, '1559847844-5315695dadae', 'Mild Khmer red curry with chicken and sweet potato.', 30],
                    ['Grilled Chicken Rice', 'rice-dishes', 2.00, '1598515214211-89d3c73ae83b', 'Lemongrass grilled chicken breast, rice and salad.', null],
                    ['Lok Lak Beef', 'rice-dishes', 2.75, '1504674900247-0877df9cc836', 'Stir-fried beef with lime-pepper dip and fried egg.', 20],
                    ['Sweet & Sour Chicken', 'rice-dishes', 2.25, '1525755662778-989d0524087e', 'Crispy chicken, pineapple and peppers, with rice.', null],
                ],
            ],
            [
                'owner' => 'owner.noodle@rupp.edu.kh', 'name' => 'Noodle House', 'building' => 'ENG',
                'location' => 'Ground floor canteen, Engineering Building', 'phone' => '012 555 003',
                'hours' => ['07:00', '19:00'], 'featured' => false, 'cover' => '1569718212165-3a8278d5f624',
                'description' => 'Kuy teav, fried noodles and ramen bowls near the Engineering Building.',
                'products' => [
                    ['Kuy Teav (Pork Noodle Soup)', 'noodles', 1.75, '1617093727343-374698b1b08d', 'Rice noodles in clear pork broth with herbs and lime.', null],
                    ['Mee Cha (Fried Noodles)', 'noodles', 1.50, '1585032226651-759b368d7246', 'Wok-fried yellow noodles with egg and greens.', null],
                    ['Spicy Ramen with Egg', 'noodles', 2.50, '1569718212165-3a8278d5f624', 'Rich broth, soft-boiled eggs and spring onion.', 20],
                    ['Bibimbap Bowl', 'rice-dishes', 3.00, '1590301157890-4810ed352733', 'Rice with vegetables, egg and gochujang.', 10],
                    ['Penne Bolognese', 'noodles', 2.25, '1621996346565-e3dbc646d9a9', 'Penne pasta in slow-cooked tomato beef sauce.', null],
                ],
            ],
            [
                'owner' => 'owner.sandwich@rupp.edu.kh', 'name' => 'Sandwich Lab', 'building' => 'STEM',
                'location' => 'STEM Building lobby kiosk', 'phone' => '012 555 004',
                'hours' => ['07:00', '18:00'], 'featured' => true, 'cover' => '1550547660-d9450f859349',
                'description' => 'Burgers, sandwiches and fried chicken built for busy STEM students.',
                'products' => [
                    ['Club Sandwich', 'sandwiches-burgers', 2.00, '1553909489-cd47e0907980', 'Chicken, bacon, egg, lettuce and tomato.', null],
                    ['Grilled Cheese Sandwich', 'sandwiches-burgers', 1.50, '1528735602780-2552fd46c7af', 'Toasted sandwich with melted cheese.', null],
                    ['Classic Beef Burger', 'sandwiches-burgers', 2.50, '1568901346375-23c9450c58cd', 'Beef patty, cheese, pickles and house sauce.', 25],
                    ['Burger & Fries Combo', 'sandwiches-burgers', 3.25, '1551782450-a2132b4ba21d', 'Classic burger with crispy fries.', 20],
                    ['Crispy Fried Chicken (2 pcs)', 'snacks', 2.50, '1626082927389-6cd097cdc6ec', 'Southern-style crispy chicken pieces.', 30],
                    ['Pizza Slice', 'snacks', 1.50, '1565299624946-b28f40a0ae38', 'Pepperoni pizza slice, baked to order.', null],
                ],
            ],
            [
                'owner' => 'owner.fresh@rupp.edu.kh', 'name' => 'Fresh Bar', 'building' => 'IFL',
                'location' => 'IFL Building courtyard', 'phone' => '012 555 005',
                'hours' => ['07:00', '20:00'], 'featured' => false, 'cover' => '1488477181946-6428a0291777',
                'description' => 'Juices, smoothies, desserts and healthy bowls.',
                'products' => [
                    ['Fresh Orange Juice', 'drinks', 1.25, '1600271886742-f049cd451bba', 'Freshly squeezed oranges, no sugar added.', null],
                    ['Iced Lemon Tea', 'drinks', 0.75, '1556679343-c7306c1976bc', 'Black tea with lime and ice.', null],
                    ['Oreo Milkshake', 'drinks', 1.75, '1572490122747-3968b75cc699', 'Vanilla ice cream blended with Oreo cookies.', null],
                    ['Strawberry Yogurt Cup', 'desserts', 1.25, '1488477181946-6428a0291777', 'Greek yogurt with fresh strawberries.', 20],
                    ['Ice Cream Cone', 'desserts', 0.75, '1497034825429-c343d7c6a68f', 'Strawberry soft-serve cone.', null],
                    ['Chocolate Sundae', 'desserts', 1.75, '1563805042-7684c019e1cb', 'Chocolate ice cream, brownie and cream.', 15],
                    ['Salmon Poke Bowl', 'healthy', 3.50, '1546069901-ba9599a7e63c', 'Salmon, rice, edamame, avocado and greens.', 8],
                    ['Garden Salad Bowl', 'healthy', 2.25, '1512621776951-a57141f2eefd', 'Mixed greens, avocado, chickpeas and vinaigrette.', null],
                ],
            ],
        ];

        foreach ($stores as $s) {
            $store = Store::updateOrCreate(['slug' => Str::slug($s['name'])], [
                'owner_id' => $owner[$s['owner']],
                'building_id' => $building[$s['building']],
                'name' => $s['name'],
                'description' => $s['description'],
                'location_note' => $s['location'],
                'phone' => $s['phone'],
                'opening_time' => $s['hours'][0],
                'closing_time' => $s['hours'][1],
                'status' => 'active',
                'is_open' => true,
                'is_featured' => $s['featured'],
                'cover_path' => $this->img($s['cover'], 1200),
                'logo_path' => $this->img($s['cover'], 200),
            ]);

            foreach ($s['products'] as [$name, $category, $price, $image, $description, $stock]) {
                $store->products()->updateOrCreate(['name' => $name], [
                    'category_id' => $cat[$category],
                    'price' => $price,
                    'image_path' => $this->img($image),
                    'description' => $description,
                    'stock_quantity' => $stock,
                    'is_available' => true,
                ]);
            }
        }

        // One product sold out, to demonstrate availability handling.
        Store::where('slug', 'sandwich-lab')->first()->products()->where('name', 'Pizza Slice')->update(['is_available' => false]);

        // A pending application for the admin to review.
        StoreApplication::updateOrCreate(['applicant_email' => 'newstore@gmail.com'], [
            'applicant_name' => 'Nhem Sokha',
            'applicant_phone' => '097 444 5566',
            'store_name' => 'Num Pang Corner',
            'description' => 'Khmer baguette sandwiches (num pang) and sugarcane juice.',
            'building_id' => $building['B'],
            'location_note' => 'Next to Building B parking',
            'status' => 'pending',
        ]);
    }
}
