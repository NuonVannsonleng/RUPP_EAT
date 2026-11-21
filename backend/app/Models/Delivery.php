<?php

namespace App\Models;

use App\Enums\DeliveryStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Delivery extends Model
{
    use HasUuids;

    protected $fillable = [
        'order_id', 'driver_id', 'status', 'requested_at', 'assigned_at', 'picked_up_at',
        'delivered_at', 'cancelled_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => DeliveryStatus::class,
            'requested_at' => 'datetime',
            'assigned_at' => 'datetime',
            'picked_up_at' => 'datetime',
            'delivered_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'driver_id')->withTrashed();
    }

    public function statusLogs(): HasMany
    {
        return $this->hasMany(DeliveryStatusLog::class)->orderBy('created_at');
    }
}
