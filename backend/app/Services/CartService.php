<?php

namespace App\Services;

use App\Enums\FulfillmentMethod;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

/** Server-side cart. A cart holds products from ONE store at a time. */
class CartService
{
    public function __construct(private PricingService $pricing) {}

    public function cartFor(User $user): Cart
    {
        return Cart::firstOrCreate(['user_id' => $user->id])
            ->load(['store.building', 'items.product.store']);
    }

    public function add(User $user, string $productId, int $quantity, ?string $note = null, bool $replaceStore = false): Cart
    {
        return DB::transaction(function () use ($user, $productId, $quantity, $note, $replaceStore) {
            $cart = Cart::firstOrCreate(['user_id' => $user->id]);
            $cart = Cart::whereKey($cart->id)->lockForUpdate()->first();
            $product = Product::with('store')->findOrFail($productId);

            if ($product->store->status !== 'active') {
                throw ValidationException::withMessages(['product_id' => 'This store is not available right now.']);
            }

            $hasItems = $cart->items()->exists();
            if ($hasItems && $cart->store_id && $cart->store_id !== $product->store_id) {
                if (! $replaceStore) {
                    throw new ConflictHttpException('Your cart has items from another store. Clear your cart to order from '.$product->store->name.'.');
                }
                $cart->items()->delete();
            }

            $item = $cart->items()->firstOrNew(['product_id' => $product->id]);
            $newQty = ($item->exists ? $item->quantity : 0) + $quantity;
            $this->assertOrderable($product, $newQty);

            $item->quantity = $newQty;
            if ($note !== null) {
                $item->note = $note;
            }
            $item->save();
            $cart->update(['store_id' => $product->store_id]);

            return $this->cartFor($user);
        });
    }

    public function updateItem(User $user, CartItem $item, int $quantity, ?string $note = null): Cart
    {
        $this->assertOwns($user, $item);

        if ($quantity <= 0) {
            return $this->removeItem($user, $item);
        }

        $this->assertOrderable($item->product, $quantity);
        $item->update(array_filter(['quantity' => $quantity, 'note' => $note], fn ($v) => $v !== null));

        return $this->cartFor($user);
    }

    public function removeItem(User $user, CartItem $item): Cart
    {
        $this->assertOwns($user, $item);
        $cart = $item->cart;
        $item->delete();

        if (! $cart->items()->exists()) {
            $cart->update(['store_id' => null]);
        }

        return $this->cartFor($user);
    }

    public function clear(User $user): Cart
    {
        $cart = Cart::firstOrCreate(['user_id' => $user->id]);
        $cart->items()->delete();
        $cart->update(['store_id' => null]);

        return $this->cartFor($user);
    }

    /** Totals + availability, used by the cart screen and checkout preview. */
    public function summary(Cart $cart, FulfillmentMethod $method = FulfillmentMethod::Delivery): array
    {
        $subtotal = 0.0;
        $unavailable = [];

        foreach ($cart->items as $item) {
            $product = $item->product;
            if (! $product || ! $product->canFulfil($item->quantity)) {
                $unavailable[] = $item->id;

                continue;
            }
            $subtotal += (float) $product->price * $item->quantity;
        }

        $subtotal = round($subtotal, 2);
        $fee = $cart->items->isEmpty() ? 0.0 : $this->pricing->deliveryFee($subtotal, $method);

        return [
            'item_count' => (int) $cart->items->sum('quantity'),
            'subtotal' => $subtotal,
            'delivery_fee' => $fee,
            'total' => round($subtotal + $fee, 2),
            'unavailable_item_ids' => $unavailable,
            'can_checkout' => $cart->items->isNotEmpty() && empty($unavailable)
                && (bool) $cart->store?->isAcceptingOrders(),
            'store_open' => (bool) $cart->store?->isAcceptingOrders(),
        ];
    }

    private function assertOrderable(Product $product, int $quantity): void
    {
        if (! $product->is_available || $product->trashed()) {
            throw ValidationException::withMessages(['product_id' => "{$product->name} is currently unavailable."]);
        }
        if ($product->stock_quantity !== null && $quantity > $product->stock_quantity) {
            throw ValidationException::withMessages(['quantity' => "Only {$product->stock_quantity} {$product->name} left in stock."]);
        }
        if ($quantity > 50) {
            throw ValidationException::withMessages(['quantity' => 'Maximum 50 of one item per order.']);
        }
    }

    private function assertOwns(User $user, CartItem $item): void
    {
        abort_unless($item->cart->user_id === $user->id, 404);
    }
}
