<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Store extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'owner_id', 'building_id', 'name', 'slug', 'description', 'logo_path', 'cover_path',
        'location_note', 'latitude', 'longitude', 'phone', 'opening_time', 'closing_time', 'status', 'is_open', 'is_featured',
    ];

    protected function casts(): array
    {
        return [
            'is_open' => 'boolean',
            'is_featured' => 'boolean',
            'latitude' => 'float',
            'longitude' => 'float',
            'rating_avg' => 'float',
            'rating_count' => 'integer',
        ];
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function staff(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'store_staff')->withTimestamps();
    }

    public function building(): BelongsTo
    {
        return $this->belongsTo(Building::class);
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(Review::class);
    }

    /** Map pin: the store's own coordinates, falling back to its building. */
    public function coordinates(): ?array
    {
        if ($this->latitude !== null && $this->longitude !== null) {
            return ['lat' => (float) $this->latitude, 'lng' => (float) $this->longitude];
        }
        $b = $this->building;

        return $b && $b->latitude !== null ? ['lat' => (float) $b->latitude, 'lng' => (float) $b->longitude] : null;
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('status', 'active');
    }

    /** Within opening hours (app timezone) AND switched open by the owner. */
    public function isAcceptingOrders(): bool
    {
        if ($this->status !== 'active' || ! $this->is_open) {
            return false;
        }

        return $this->isWithinOpeningHours();
    }

    public function isWithinOpeningHours(): bool
    {
        $now = now()->format('H:i:s');
        $open = substr((string) $this->opening_time, 0, 8);
        $close = substr((string) $this->closing_time, 0, 8);

        return $open <= $close
            ? ($now >= $open && $now <= $close)
            : ($now >= $open || $now <= $close); // overnight opening hours
    }
}
