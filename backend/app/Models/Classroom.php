<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Classroom extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = ['floor_id', 'name', 'type', 'is_deliverable'];

    protected function casts(): array
    {
        return ['is_deliverable' => 'boolean'];
    }

    public function floor(): BelongsTo
    {
        return $this->belongsTo(Floor::class);
    }

    /** Snapshot stored on orders so order history survives later campus edits. */
    public function locationSnapshot(): array
    {
        $this->loadMissing('floor.building.faculty');
        $building = $this->floor->building;

        return [
            'classroom_id' => $this->id,
            'faculty' => $building->faculty?->name,
            'building' => $building->name,
            'building_code' => $building->code,
            'floor' => $this->floor->number,
            'floor_label' => $this->floor->label,
            'room' => $this->name,
            // Destination pin for maps (building centre, WGS84)
            'latitude' => $building->latitude,
            'longitude' => $building->longitude,
        ];
    }
}
