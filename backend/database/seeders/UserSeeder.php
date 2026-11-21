<?php

namespace Database\Seeders;

use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;

/** Demo accounts. Every password is "password123". */
class UserSeeder extends Seeder
{
    public const PASSWORD = 'password123';

    public function run(): void
    {
        $role = fn (string $name) => Role::idFor($name);

        $this->user('admin@rupp.edu.kh', [
            'role_id' => $role('admin'), 'name' => 'RUPP Eat Admin', 'phone' => '012 000 001', 'university_id' => 'ADMIN-001',
        ]);

        // Store owners
        $owners = [
            ['owner.cafe@rupp.edu.kh', 'Sok Dara', '012 111 101'],
            ['owner.khmer@rupp.edu.kh', 'Chan Sophea', '012 111 102'],
            ['owner.noodle@rupp.edu.kh', 'Lim Vuthy', '012 111 103'],
            ['owner.sandwich@rupp.edu.kh', 'Keo Sreyneang', '012 111 104'],
            ['owner.fresh@rupp.edu.kh', 'Heng Rotha', '012 111 105'],
        ];
        foreach ($owners as [$email, $name, $phone]) {
            $this->user($email, ['role_id' => $role('store_owner'), 'name' => $name, 'phone' => $phone]);
        }

        // Drivers: two verified, one waiting for admin verification
        $drivers = [
            ['driver1@rupp.edu.kh', 'Pich Samnang', '015 222 201', 'motorbike', '1AB-2345', 'verified', true],
            ['driver2@rupp.edu.kh', 'Mao Kosal', '015 222 202', 'bicycle', null, 'verified', false],
            ['driver3@rupp.edu.kh', 'Ouk Sambath', '015 222 203', 'motorbike', '2CD-6789', 'pending', false],
        ];
        foreach ($drivers as [$email, $name, $phone, $vehicle, $plate, $verification, $online]) {
            $u = $this->user($email, ['role_id' => $role('driver'), 'name' => $name, 'phone' => $phone]);
            $u->driverProfile()->updateOrCreate([], [
                'vehicle_type' => $vehicle,
                'plate_number' => $plate,
                'verification_status' => $verification,
                'verified_at' => $verification === 'verified' ? now()->subMonth() : null,
                'is_online' => $online,
                'is_active' => true,
            ]);
        }

        // Customers: students, a lecturer and a staff member (login with email or ID)
        $customers = [
            ['student@rupp.edu.kh', 'Srey Leak', 'e20230001', 'student', '010 333 301'],
            ['vannak.student@rupp.edu.kh', 'Vannak Chea', 'e20230002', 'student', '010 333 302'],
            ['bopha.student@rupp.edu.kh', 'Bopha Nuon', 'e20220045', 'student', '010 333 303'],
            ['rithy.student@rupp.edu.kh', 'Rithy Long', 'e20210118', 'student', '010 333 304'],
            ['lecturer@rupp.edu.kh', 'Dr. Sothea Prak', 'L-0042', 'lecturer', '010 333 305'],
            ['staff@rupp.edu.kh', 'Malis Tep', 'S-0107', 'staff', '010 333 306'],
        ];
        foreach ($customers as [$email, $name, $id, $type, $phone]) {
            $this->user($email, ['role_id' => $role('customer'), 'name' => $name, 'university_id' => strtoupper($id), 'user_type' => $type, 'phone' => $phone]);
        }
    }

    private function user(string $email, array $attrs): User
    {
        return User::updateOrCreate(['email' => $email], $attrs + ['password' => self::PASSWORD, 'status' => 'active', 'email_verified_at' => now()]);
    }
}
