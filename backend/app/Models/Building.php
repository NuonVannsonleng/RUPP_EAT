<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Building extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = ['faculty_id', 'name', 'code', 'description', 'latitude', 'longitude', 'polygon', 'official_map_no', 'is_active'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean', 'latitude' => 'float', 'longitude' => 'float', 'polygon' => 'array', 'official_map_no' => 'integer'];
    }

    public function faculty(): BelongsTo
    {
        return $this->belongsTo(Faculty::class);
    }

    public function floors(): HasMany
    {
        return $this->hasMany(Floor::class)->orderBy('number');
    }

    public function stores(): HasMany
    {
        return $this->hasMany(Store::class);
    }
}
