<?php

namespace Database\Seeders;

use App\Models\Role;
use Illuminate\Database\Seeder;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $roles = [
            ['name' => 'customer', 'display_name' => 'Customer', 'description' => 'RUPP student, lecturer or staff who orders food (mobile app).'],
            ['name' => 'driver', 'display_name' => 'Driver', 'description' => 'Delivers orders to classrooms (mobile app, driver mode).'],
            ['name' => 'store_owner', 'display_name' => 'Store Owner', 'description' => 'Manages a campus store, menu and orders (web dashboard).'],
            ['name' => 'admin', 'display_name' => 'Administrator', 'description' => 'Full platform management (web dashboard).'],
        ];

        foreach ($roles as $role) {
            Role::updateOrCreate(['name' => $role['name']], $role);
        }
    }
}
