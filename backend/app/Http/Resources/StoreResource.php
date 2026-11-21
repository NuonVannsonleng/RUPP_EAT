<?php

namespace App\Http\Resources;

use App\Support\Media;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StoreResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'description' => $this->description,
            'logo_url' => Media::url($this->logo_path),
            'cover_url' => Media::url($this->cover_path),
            'location_note' => $this->location_note,
            'latitude' => $this->coordinates()['lat'] ?? null,
            'longitude' => $this->coordinates()['lng'] ?? null,
            'phone' => $this->phone,
            'opening_time' => substr((string) $this->opening_time, 0, 5),
            'closing_time' => substr((string) $this->closing_time, 0, 5),
            'status' => $this->status,
            'is_open' => $this->is_open,
            'is_open_now' => $this->isAcceptingOrders(),
            'is_featured' => $this->is_featured,
            'rating_avg' => round((float) $this->rating_avg, 1),
            'rating_count' => $this->rating_count,
            'building' => $this->whenLoaded('building', fn () => $this->building ? [
                'id' => $this->building->id,
                'name' => $this->building->name,
                'code' => $this->building->code,
            ] : null),
            'owner' => $this->whenLoaded('owner', fn () => [
                'id' => $this->owner->id,
                'name' => $this->owner->name,
                'email' => $this->owner->email,
                'phone' => $this->owner->phone,
            ]),
            'products_count' => $this->whenCounted('products'),
            'orders_count' => $this->whenCounted('orders'),
            'is_favorite' => $this->when(isset($this->is_favorite), fn () => (bool) $this->is_favorite),
            'created_at' => $this->created_at,
        ];
    }
}
