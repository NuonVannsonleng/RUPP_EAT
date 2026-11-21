<?php

namespace Database\Seeders;

use App\Models\Classroom;
use App\Models\Order;
use App\Models\Product;
use App\Models\Review;
use App\Models\Store;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * 30 days of realistic order history (for dashboards/reports) plus a few LIVE orders
 * so every role has something to act on right after seeding:
 *   - pending pickup + pending delivery   -> store owner can accept
 *   - preparing delivery                   -> store can mark ready
 *   - ready delivery, driver searching     -> driver1 can accept in the app
 */
class OrderHistorySeeder extends Seeder
{
    private array $pipeline = ['pending', 'accepted', 'preparing', 'ready', 'driver_assigned', 'on_the_way'];

    public function run(): void
    {
        mt_srand(2026);
        $customers = User::whereHas('role', fn ($q) => $q->where('name', 'customer'))->get();
        $drivers = User::whereHas('driverProfile', fn ($q) => $q->where('verification_status', 'verified'))->get();
        $stores = Store::with('products')->get();
        $classrooms = Classroom::with('floor.building.faculty')->where('type', 'classroom')->get();
        $fee = 0.50;

        DB::transaction(function () use ($customers, $drivers, $stores, $classrooms, $fee) {
            // ---------- History ----------
            for ($day = 30; $day >= 1; $day--) {
                $perDay = mt_rand(3, 8);
                for ($n = 0; $n < $perDay; $n++) {
                    $at = Carbon::today()->subDays($day)->setTime(mt_rand(7, 17), mt_rand(0, 59));
                    $roll = mt_rand(1, 100);
                    $status = $roll <= 8 ? 'cancelled' : ($roll <= 11 ? 'rejected' : null);
                    $this->makeOrder($customers->random(), $stores->random(), $classrooms, $drivers, $fee, $at, $status);
                }
            }

            // ---------- Live orders (today) ----------
            $student = $customers->firstWhere('email', 'student@rupp.edu.kh');
            $cafe = $stores->firstWhere('slug', 'campus-cafe');
            $khmer = $stores->firstWhere('slug', 'khmer-kitchen');
            $now = now();

            $this->makeOrder($customers[1], $cafe, $classrooms, $drivers, $fee, $now->copy()->subMinutes(3), 'pending', 'pickup');
            $this->makeOrder($customers[2], $cafe, $classrooms, $drivers, $fee, $now->copy()->subMinutes(2), 'pending', 'delivery');
            $this->makeOrder($customers[3], $khmer, $classrooms, $drivers, $fee, $now->copy()->subMinutes(12), 'preparing', 'delivery');
            $this->makeOrder($student, $cafe, $classrooms, $drivers, $fee, $now->copy()->subMinutes(18), 'ready', 'delivery');
        });

        $this->refreshRatings();
    }

    private function makeOrder($customer, Store $store, $classrooms, $drivers, float $fee, Carbon $at, ?string $forced = null, ?string $method = null): Order
    {
        $method ??= mt_rand(1, 100) <= 60 ? 'delivery' : 'pickup';
        $products = $store->products->where('is_available', true)->shuffle()->take(mt_rand(1, 3));

        $subtotal = 0;
        $lines = [];
        foreach ($products as $p) {
            $qty = mt_rand(1, 2);
            $line = round((float) $p->price * $qty, 2);
            $subtotal += $line;
            $lines[] = [$p, $qty, $line];
        }
        $deliveryFee = $method === 'delivery' && $subtotal < 10 ? $fee : 0;

        $status = $forced ?? ($method === 'delivery' ? 'delivered' : 'picked_up');
        $completed = in_array($status, ['delivered', 'picked_up'], true);
        $classroom = $method === 'delivery' ? $classrooms->random() : null;
        $driver = $method === 'delivery' && ($completed || in_array($status, ['driver_assigned', 'on_the_way'], true)) ? $drivers->random() : null;

        $order = Order::create([
            'order_number' => 'RE-'.$at->format('ymd').'-'.strtoupper(Str::random(4)),
            'customer_id' => $customer->id,
            'store_id' => $store->id,
            'driver_id' => $driver?->id,
            'fulfillment_method' => $method,
            'payment_method' => $method === 'delivery' ? 'cash_on_delivery' : 'cash_on_pickup',
            'payment_status' => $completed ? 'paid' : (in_array($status, ['cancelled', 'rejected'], true) ? 'cancelled' : 'unpaid'),
            'status' => $status,
            'subtotal' => $subtotal,
            'delivery_fee' => $deliveryFee,
            'total' => $subtotal + $deliveryFee,
            'classroom_id' => $classroom?->id,
            'delivery_location' => $classroom?->locationSnapshot(),
            'delivery_instructions' => $classroom && mt_rand(0, 1) ? 'Please call me when you arrive.' : null,
            'pickup_code' => (string) mt_rand(1000, 9999),
            'accepted_at' => $status !== 'pending' && $status !== 'rejected' ? $at->copy()->addMinutes(2) : null,
            'ready_at' => $completed ? $at->copy()->addMinutes(12) : null,
            'completed_at' => $completed ? $at->copy()->addMinutes($method === 'delivery' ? 25 : 18) : null,
            'cancelled_at' => in_array($status, ['cancelled', 'rejected'], true) ? $at->copy()->addMinutes(3) : null,
            'cancel_reason' => match ($status) {
                'cancelled' => 'Changed my mind',
                'rejected' => 'Sold out for today',
                default => null,
            },
            'created_at' => $at,
            'updated_at' => $at,
        ]);

        foreach ($lines as [$p, $qty, $line]) {
            $order->items()->create([
                'product_id' => $p->id, 'product_name' => $p->name, 'unit_price' => $p->price,
                'quantity' => $qty, 'line_total' => $line,
            ]);
            if ($completed) {
                Product::whereKey($p->id)->increment('sold_count', $qty);
            }
        }

        $order->payments()->create([
            'method' => $order->payment_method, 'amount' => $order->total, 'provider' => 'cash',
            'status' => $completed ? 'paid' : ($order->payment_status->value === 'cancelled' ? 'cancelled' : 'pending'),
            'paid_at' => $order->completed_at, 'collected_by' => $completed ? ($driver?->id ?? $store->owner_id) : null,
        ]);

        // Status timeline
        $path = match (true) {
            $status === 'rejected' => ['pending', 'rejected'],
            $status === 'cancelled' => ['pending', 'cancelled'],
            $completed && $method === 'delivery' => ['pending', 'accepted', 'preparing', 'ready', 'driver_assigned', 'on_the_way', 'delivered'],
            $completed => ['pending', 'accepted', 'preparing', 'ready', 'picked_up'],
            default => array_slice($this->pipeline, 0, array_search($status, $this->pipeline, true) + 1),
        };
        $prev = null;
        foreach ($path as $i => $s) {
            $order->statusLogs()->create(['from_status' => $prev, 'to_status' => $s, 'changed_by' => null, 'created_at' => $at->copy()->addMinutes($i * 4)]);
            $prev = $s;
        }

        if ($method === 'delivery') {
            $deliveryStatus = match (true) {
                $completed => 'delivered',
                in_array($status, ['cancelled', 'rejected'], true) => 'cancelled',
                $status === 'ready' => 'searching',
                $status === 'driver_assigned' => 'assigned',
                $status === 'on_the_way' => 'picked_up',
                default => 'pending',
            };
            $order->delivery()->create([
                'driver_id' => $driver?->id,
                'status' => $deliveryStatus,
                'requested_at' => in_array($deliveryStatus, ['searching', 'assigned', 'picked_up', 'delivered'], true) ? $at->copy()->addMinutes(10) : null,
                'assigned_at' => $driver ? $at->copy()->addMinutes(11) : null,
                'picked_up_at' => $completed ? $at->copy()->addMinutes(15) : null,
                'delivered_at' => $completed ? $order->completed_at : null,
                'created_at' => $at,
                'updated_at' => $order->completed_at ?? $at,
            ]);
        }

        if ($completed && mt_rand(1, 100) <= 40) {
            Review::create([
                'user_id' => $customer->id, 'order_id' => $order->id, 'store_id' => $store->id,
                'rating' => mt_rand(3, 5), 'comment' => ['Delicious and fast!', 'Arrived hot at my classroom.', 'Good portion for the price.', null][mt_rand(0, 3)],
                'created_at' => $order->completed_at,
            ]);
        }

        return $order;
    }

    private function refreshRatings(): void
    {
        foreach (Store::all() as $store) {
            $stats = Review::where('store_id', $store->id)->whereNull('product_id')->selectRaw('AVG(rating) a, COUNT(*) c')->first();
            $store->forceFill(['rating_avg' => round((float) $stats->a, 2), 'rating_count' => (int) $stats->c])->save();
        }
    }
}
