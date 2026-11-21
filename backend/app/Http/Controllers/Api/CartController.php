<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CartResource;
use App\Models\CartItem;
use App\Services\CartService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CartController extends Controller
{
    public function __construct(private CartService $cart) {}

    /** GET /api/cart?fulfillment_method=delivery|pickup */
    public function show(Request $request): JsonResponse
    {
        return $this->ok(new CartResource($this->cart->cartFor($request->user())));
    }

    /** POST /api/cart/items {product_id, quantity, note?, replace?} */
    public function add(Request $request): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
            'quantity' => ['required', 'integer', 'min:1', 'max:50'],
            'note' => ['nullable', 'string', 'max:200'],
            'replace' => ['sometimes', 'boolean'],
        ]);

        $cart = $this->cart->add($request->user(), $data['product_id'], $data['quantity'], $data['note'] ?? null, $data['replace'] ?? false);

        return $this->ok(new CartResource($cart), 'Added to cart.');
    }

    /** PATCH /api/cart/items/{item} {quantity, note?} — quantity 0 removes the item. */
    public function update(Request $request, CartItem $item): JsonResponse
    {
        $data = $request->validate([
            'quantity' => ['required', 'integer', 'min:0', 'max:50'],
            'note' => ['nullable', 'string', 'max:200'],
        ]);

        return $this->ok(new CartResource($this->cart->updateItem($request->user(), $item, $data['quantity'], $data['note'] ?? null)));
    }

    public function remove(Request $request, CartItem $item): JsonResponse
    {
        return $this->ok(new CartResource($this->cart->removeItem($request->user(), $item)), 'Item removed.');
    }

    public function clear(Request $request): JsonResponse
    {
        return $this->ok(new CartResource($this->cart->clear($request->user())), 'Cart cleared.');
    }
}
