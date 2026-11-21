<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * php artisan migrate:fresh --seed
     * Demo accounts (password for all: password123) are listed in README.md.
     */
    public function run(): void
    {
        $this->call([
            RoleSeeder::class,
            SettingSeeder::class,
            CampusSeeder::class,
            CategorySeeder::class,
            UserSeeder::class,
            StoreSeeder::class,
            AnnouncementSeeder::class,
            OrderHistorySeeder::class,
        ]);
    }
}
