<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DriverProfile extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id', 'vehicle_type', 'plate_number', 'national_id', 'verification_status',
        'verified_at', 'verified_by', 'is_active', 'is_online', 'last_online_at',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'is_online' => 'boolean',
            'verified_at' => 'datetime',
            'last_online_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isVerified(): bool
    {
        return $this->verification_status === 'verified';
    }

    /** A driver may receive requests only when verified, active and online. */
    public function canReceiveRequests(): bool
    {
        return $this->isVerified() && $this->is_active && $this->is_online;
    }
}
