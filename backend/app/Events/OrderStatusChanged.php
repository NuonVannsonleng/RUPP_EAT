<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/** Fired on every order status transition; broadcast to customer, store and driver channels. */
class OrderStatusChanged implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Order $order,
        public ?string $fromStatus,
        public string $toStatus,
    ) {}

    public function broadcastOn(): array
    {
        $channels = [
            new PrivateChannel('orders.'.$this->order->id),
            new PrivateChannel('users.'.$this->order->customer_id),
            new PrivateChannel('stores.'.$this->order->store_id),
        ];
        if ($this->order->driver_id) {
            $channels[] = new PrivateChannel('users.'.$this->order->driver_id);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'order.status';
    }

    public function broadcastWith(): array
    {
        return [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'from' => $this->fromStatus,
            'status' => $this->toStatus,
        ];
    }
}
