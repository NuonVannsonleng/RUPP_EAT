<?php

namespace App\Events;

use App\Models\Delivery;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/** A store released a delivery order to the driver pool. */
class DeliveryRequested implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public Delivery $delivery) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('drivers')];
    }

    public function broadcastAs(): string
    {
        return 'delivery.requested';
    }

    public function broadcastWith(): array
    {
        return ['delivery_id' => $this->delivery->id, 'order_id' => $this->delivery->order_id];
    }
}
