<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeliveryStatusLog extends Model
{
    use HasUuids;

    public const UPDATED_AT = null;

    protected $fillable = ['delivery_id', 'status', 'changed_by', 'note'];

    protected function casts(): array
    {
        return ['created_at' => 'datetime'];
    }

    public function delivery(): BelongsTo
    {
        return $this->belongsTo(Delivery::class);
    }
}
