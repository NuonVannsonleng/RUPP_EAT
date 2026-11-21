<?php

namespace App\Http\Resources;

use App\Enums\FulfillmentMethod;
use App\Services\CartService;
use App\Support\Media;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CartResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $method = FulfillmentMethod::tryFrom((string) $request->query('fulfillment_method')) ?? FulfillmentMethod::Delivery;

        return [
            'id' => $this->id,
            'store' => $this->store ? new StoreResource($this->store) : null,
            'items' => $this->items->map(fn ($item) => [
                'id' => $item->id,
                'quantity' => $item->quantity,
                'note' => $item->note,
                'line_total' => round((float) $item->product->price * $item->quantity, 2),
                'available' => $item->product->canFulfil($item->quantity),
                'product' => [
                    'id' => $item->product->id,
                    'name' => $item->product->name,
                    'price' => (float) $item->product->price,
                    'image_url' => Media::url($item->product->image_path),
                    'stock_quantity' => $item->product->stock_quantity,
                    'is_available' => $item->product->is_available && ! $item->product->trashed(),
                ],
            ])->values(),
            'summary' => app(CartService::class)->summary($this->resource, $method),
        ];
    }
}
