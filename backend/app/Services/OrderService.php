<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\FulfillmentMethod;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Events\OrderStatusChanged;
use App\Models\Cart;
use App\Models\Classroom;
use App\Models\Order;
use App\Models\Product;
use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/** Turns the customer's server-side cart into an order, atomically. */
class OrderService
{
    public function __construct(
        private PricingService $pricing,
        private NotificationService $notifications,
    ) {}

    /**
     * @param  array{fulfillment_method:string, payment_method:string, classroom_id?:string,
     *               delivery_instructions?:string, customer_note?:string}  $data
     * @return array{0: Order, 1: bool} [order, wasCreated]
     */
    public function place(User $customer, array $data, ?string $idempotencyKey): array
    {
        // Duplicate submission (double tap / network retry) -> return the original order.
        if ($idempotencyKey && $existing = $this->findByKey($customer, $idempotencyKey)) {
            return [$existing, false];
        }

        $method = FulfillmentMethod::from($data['fulfillment_method']);
        $payment = PaymentMethod::from($data['payment_method']);
        $this->assertMethodsAllowed($method, $payment);

        try {
            $order = DB::transaction(fn () => $this->createFromCart($customer, $data, $method, $payment, $idempotencyKey));
        } catch (UniqueConstraintViolationException $e) {
            // A concurrent request with the same idempotency key won the race.
            if ($idempotencyKey && $existing = $this->findByKey($customer, $idempotencyKey)) {
                return [$existing, false];
            }
            throw $e;
        }

        $order->load('store');
        $this->notifications->newOrderForStore($order);
        ActivityLogger::log('order.created', "Order {$order->order_number} placed", $order, ['total' => $order->total]);
        event(new OrderStatusChanged($order, null, OrderStatus::Pending->value));

        return [$order, true];
    }

    private function createFromCart(User $customer, array $data, FulfillmentMethod $method, PaymentMethod $payment, ?string $key): Order
    {
        $cart = Cart::where('user_id', $customer->id)->lockForUpdate()->first();
        $items = $cart?->items()->get() ?? collect();

        if ($items->isEmpty()) {
            throw ValidationException::withMessages(['cart' => 'Your cart is empty.']);
        }

        $store = $cart->store()->lockForUpdate()->first();
        if (! $store || ! $store->isAcceptingOrders()) {
            throw ValidationException::withMessages(['store' => ($store->name ?? 'This store').' is closed and cannot take orders right now.']);
        }

        // Lock product rows so concurrent orders cannot oversell stock.
        $products = Product::whereIn('id', $items->pluck('product_id'))
            ->where('store_id', $store->id)
            ->lockForUpdate()
            ->get()
            ->keyBy('id');

        $subtotal = 0.0;
        $lines = [];
        foreach ($items as $item) {
            $product = $products->get($item->product_id);
            if (! $product || ! $product->canFulfil($item->quantity)) {
                $name = $product->name ?? 'An item';
                throw ValidationException::withMessages(['cart' => "$name is unavailable or out of stock. Please update your cart."]);
            }
            $lineTotal = round((float) $product->price * $item->quantity, 2);
            $subtotal += $lineTotal;
            $lines[] = [$product, $item, $lineTotal];
        }
        $subtotal = round($subtotal, 2);

        $min = $this->pricing->minimumOrder();
        if ($min > 0 && $subtotal < $min) {
            throw ValidationException::withMessages(['cart' => 'Minimum order is $'.number_format($min, 2).'.']);
        }

        $classroom = null;
        if ($method === FulfillmentMethod::Delivery) {
            $classroom = Classroom::with('floor.building.faculty')->find($data['classroom_id'] ?? null);
            if (! $classroom || ! $classroom->is_deliverable || ! $classroom->floor->building->is_active) {
                throw ValidationException::withMessages(['classroom_id' => 'Please choose a valid delivery classroom.']);
            }
        }

        $fee = $this->pricing->deliveryFee($subtotal, $method);

        $order = Order::create([
            'order_number' => $this->generateOrderNumber(),
            'customer_id' => $customer->id,
            'store_id' => $store->id,
            'fulfillment_method' => $method,
            'payment_method' => $payment,
            'payment_status' => PaymentStatus::Unpaid,
            'status' => OrderStatus::Pending,
            'subtotal' => $subtotal,
            'delivery_fee' => $fee,
            'total' => round($subtotal + $fee, 2),
            'classroom_id' => $classroom?->id,
            'delivery_location' => $classroom?->locationSnapshot(),
            'delivery_instructions' => $method === FulfillmentMethod::Delivery ? ($data['delivery_instructions'] ?? null) : null,
            'customer_note' => $data['customer_note'] ?? null,
            'pickup_code' => (string) random_int(1000, 9999),
            'idempotency_key' => $key,
        ]);

        foreach ($lines as [$product, $item, $lineTotal]) {
            $order->items()->create([
                'product_id' => $product->id,
                'product_name' => $product->name,
                'unit_price' => $product->price,
                'quantity' => $item->quantity,
                'line_total' => $lineTotal,
                'note' => $item->note,
            ]);
            if ($product->stock_quantity !== null) {
                $product->decrement('stock_quantity', $item->quantity);
            }
        }

        $order->payments()->create([
            'method' => $payment,
            'amount' => $order->total,
            'status' => PaymentStatus::Pending,
            'provider' => $payment->isCash() ? 'cash' : 'bakong',
        ]);

        if ($method === FulfillmentMethod::Delivery) {
            $order->delivery()->create(['status' => DeliveryStatus::Pending]);
        }

        $order->statusLogs()->create([
            'to_status' => OrderStatus::Pending->value,
            'changed_by' => $customer->id,
            'note' => 'Order placed',
        ]);

        $cart->items()->delete();
        $cart->update(['store_id' => null]);

        return $order;
    }

    private function assertMethodsAllowed(FulfillmentMethod $method, PaymentMethod $payment): void
    {
        if ($method === FulfillmentMethod::Delivery && ! SystemSetting::get('delivery_enabled', true)) {
            throw ValidationException::withMessages(['fulfillment_method' => 'Classroom delivery is temporarily unavailable. Please choose pickup.']);
        }
        if ($payment === PaymentMethod::Khqr) {
            // Real Bakong/KHQR verification is not configured. Never fake a successful payment.
            if (! config('services.khqr.enabled')) {
                throw ValidationException::withMessages(['payment_method' => 'Bakong KHQR payment is coming soon. Please pay with cash.']);
            }
        }
        if ($payment === PaymentMethod::CashOnDelivery && $method !== FulfillmentMethod::Delivery) {
            throw ValidationException::withMessages(['payment_method' => 'Cash on delivery is only for delivery orders.']);
        }
        if ($payment === PaymentMethod::CashOnPickup && $method !== FulfillmentMethod::Pickup) {
            throw ValidationException::withMessages(['payment_method' => 'Cash on pickup is only for pickup orders.']);
        }
    }

    private function findByKey(User $customer, string $key): ?Order
    {
        return Order::where('customer_id', $customer->id)->where('idempotency_key', $key)->first();
    }

    private function generateOrderNumber(): string
    {
        do {
            $number = 'RE-'.now()->format('ymd').'-'.strtoupper(Str::random(4));
        } while (Order::where('order_number', $number)->exists());

        return $number;
    }
}
