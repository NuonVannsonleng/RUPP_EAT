<?php

namespace App\Http\Resources;

use App\Support\Media;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * What a driver sees. Customer contact details are only included once the
 * delivery is assigned to the requesting driver.
 */
class DeliveryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $order = $this->order;
        $isAssignedDriver = $request->user()?->id === $this->driver_id;
        $isAdmin = (bool) $request->user()?->isAdmin();

        return [
            'id' => $this->id,
            'status' => $this->status->value,
            'requested_at' => $this->requested_at,
            'assigned_at' => $this->assigned_at,
            'picked_up_at' => $this->picked_up_at,
            'delivered_at' => $this->delivered_at,
            'cancelled_at' => $this->cancelled_at,
            'order' => [
                'id' => $order->id,
                'order_number' => $order->order_number,
                'status' => $order->status->value,
                'status_label' => $order->status->label(),
                'payment_method' => $order->payment_method->value,
                'payment_method_label' => $order->payment_method->label(),
                'payment_status' => $order->payment_status->value,
                'subtotal' => (float) $order->subtotal,
                'delivery_fee' => (float) $order->delivery_fee,
                'total' => (float) $order->total,
                'item_count' => $order->items->sum('quantity'),
                'items' => $order->items->map(fn ($i) => ['name' => $i->product_name, 'quantity' => $i->quantity, 'note' => $i->note]),
                'delivery_location' => $order->delivery_location,
                'delivery_instructions' => $order->delivery_instructions,
                'created_at' => $order->created_at,
            ],
            'store' => [
                'id' => $order->store->id,
                'name' => $order->store->name,
                'logo_url' => Media::url($order->store->logo_path),
                'phone' => $order->store->phone,
                'location_note' => $order->store->location_note,
                'building' => $order->store->building?->name,
            ],
            'customer' => ($isAssignedDriver || $isAdmin) ? [
                'name' => $order->customer->name,
                'phone' => $order->customer->phone,
            ] : null,
        ];
    }
}
