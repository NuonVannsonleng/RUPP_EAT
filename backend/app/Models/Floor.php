<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Floor extends Model
{
    use HasUuids;

    protected $fillable = ['building_id', 'number', 'label'];

    protected function casts(): array
    {
        return ['number' => 'integer'];
    }

    public function building(): BelongsTo
    {
        return $this->belongsTo(Building::class);
    }

    public function classrooms(): HasMany
    {
        return $this->hasMany(Classroom::class)->orderBy('name');
    }
}
