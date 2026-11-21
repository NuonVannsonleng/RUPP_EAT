<?php

namespace Database\Seeders;

use App\Models\ProductCategory;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class CategorySeeder extends Seeder
{
    public function run(): void
    {
        // icon = Material icon name, rendered by the Flutter app and the dashboard.
        $categories = [
            ['Rice Dishes', 'rice_bowl'],
            ['Noodles', 'ramen_dining'],
            ['Sandwiches & Burgers', 'lunch_dining'],
            ['Snacks', 'fastfood'],
            ['Coffee', 'local_cafe'],
            ['Drinks', 'local_drink'],
            ['Desserts', 'icecream'],
            ['Healthy', 'eco'],
            ['Breakfast', 'egg_alt'],
        ];

        foreach ($categories as $i => [$name, $icon]) {
            ProductCategory::updateOrCreate(['slug' => Str::slug($name)], ['name' => $name, 'icon' => $icon, 'sort_order' => $i]);
        }
    }
}
