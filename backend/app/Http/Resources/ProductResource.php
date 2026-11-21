<?php

namespace App\Http\Resources;

use App\Support\Media;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'store_id' => $this->store_id,
            'name' => $this->name,
            'description' => $this->description,
            'price' => (float) $this->price,
            'image_url' => Media::url($this->image_path),
            'stock_quantity' => $this->stock_quantity,
            'is_available' => $this->is_available,
            'in_stock' => $this->canFulfil(1),
            'sold_count' => $this->sold_count,
            'rating_avg' => round((float) $this->rating_avg, 1),
            'rating_count' => $this->rating_count,
            'category' => $this->whenLoaded('category', fn () => $this->category ? [
                'id' => $this->category->id,
                'name' => $this->category->name,
                'slug' => $this->category->slug,
            ] : null),
            'store' => $this->whenLoaded('store', fn () => [
                'id' => $this->store->id,
                'name' => $this->store->name,
                'logo_url' => Media::url($this->store->logo_path),
                'is_open_now' => $this->store->isAcceptingOrders(),
            ]),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
