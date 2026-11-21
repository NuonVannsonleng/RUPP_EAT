<?php

namespace App\Http\Resources;

use App\Enums\OrderStatus;
use App\Support\Media;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $user = $request->user();
        $isCustomer = $user && $user->id === $this->customer_id;
        $isDriver = $user && $user->id === $this->driver_id;
        $isStaffOrAdmin = $user && ($user->isAdmin() || $user->canManageStore($this->store_id));

        return [
            'id' => $this->id,
            'order_number' => $this->order_number,
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'fulfillment_method' => $this->fulfillment_method->value,
            'payment_method' => $this->payment_method->value,
            'payment_method_label' => $this->payment_method->label(),
            'payment_status' => $this->payment_status->value,
            'subtotal' => (float) $this->subtotal,
            'delivery_fee' => (float) $this->delivery_fee,
            'total' => (float) $this->total,
            'delivery_location' => $this->delivery_location,
            'delivery_instructions' => $this->delivery_instructions,
            'customer_note' => $this->customer_note,
            // Pickup code: the customer shows it, the store verifies it. Never sent to drivers.
            'pickup_code' => $this->when($isCustomer || $user?->isAdmin(), $this->pickup_code),
            'cancel_reason' => $this->cancel_reason,
            'can_cancel' => $isCustomer && $this->status === OrderStatus::Pending,
            'can_review' => $isCustomer && $this->status->isCompleted(),
            'is_reviewed' => $this->whenLoaded('reviews', fn () => $this->reviews->whereNull('product_id')->isNotEmpty()),
            'item_count' => $this->whenLoaded('items', fn () => $this->items->sum('quantity')),
            'items' => $this->whenLoaded('items', fn () => $this->items->map(fn ($i) => [
                'id' => $i->id,
                'product_id' => $i->product_id,
                'product_name' => $i->product_name,
                'image_url' => Media::url($i->product?->image_path),
                'unit_price' => (float) $i->unit_price,
                'quantity' => $i->quantity,
                'line_total' => (float) $i->line_total,
                'note' => $i->note,
            ])),
            'store' => $this->whenLoaded('store', fn () => [
                'id' => $this->store->id,
                'name' => $this->store->name,
                'logo_url' => Media::url($this->store->logo_path),
                'phone' => $this->store->phone,
                'location_note' => $this->store->location_note,
                'building' => $this->store->building?->name,
            ]),
            'customer' => $this->whenLoaded('customer', fn () => ($isStaffOrAdmin || $isDriver) ? [
                'id' => $this->customer->id,
                'name' => $this->customer->name,
                'phone' => $this->customer->phone,
                'university_id' => $isStaffOrAdmin ? $this->customer->university_id : null,
                'email' => $user?->isAdmin() ? $this->customer->email : null,
            ] : null),
            'driver' => $this->whenLoaded('driver', fn () => $this->driver ? [
                'id' => $this->driver->id,
                'name' => $this->driver->name,
                'phone' => $this->driver->phone,
            ] : null),
            'delivery' => $this->whenLoaded('delivery', fn () => $this->delivery ? [
                'id' => $this->delivery->id,
                'status' => $this->delivery->status->value,
                'requested_at' => $this->delivery->requested_at,
                'assigned_at' => $this->delivery->assigned_at,
                'picked_up_at' => $this->delivery->picked_up_at,
                'delivered_at' => $this->delivery->delivered_at,
            ] : null),
            'timeline' => $this->whenLoaded('statusLogs', fn () => $this->statusLogs->map(fn ($l) => [
                'status' => $l->to_status,
                'label' => OrderStatus::tryFrom($l->to_status)?->label() ?? $l->to_status,
                'note' => $l->note,
                'at' => $l->created_at,
            ])),
            'accepted_at' => $this->accepted_at,
            'ready_at' => $this->ready_at,
            'completed_at' => $this->completed_at,
            'cancelled_at' => $this->cancelled_at,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
