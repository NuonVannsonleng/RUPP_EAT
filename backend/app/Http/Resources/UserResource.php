<?php

namespace App\Http\Resources;

use App\Support\Media;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'university_id' => $this->university_id,
            'user_type' => $this->user_type,
            'phone' => $this->phone,
            'avatar_url' => Media::url($this->avatar_path),
            'status' => $this->status,
            'role' => $this->whenLoaded('role', fn () => $this->role->name),
            'role_name' => $this->whenLoaded('role', fn () => $this->role->display_name),
            'driver_profile' => $this->whenLoaded('driverProfile', fn () => $this->driverProfile ? [
                'vehicle_type' => $this->driverProfile->vehicle_type,
                'plate_number' => $this->driverProfile->plate_number,
                'verification_status' => $this->driverProfile->verification_status,
                'verified_at' => $this->driverProfile->verified_at,
                'is_active' => $this->driverProfile->is_active,
                'is_online' => $this->driverProfile->is_online,
            ] : null),
            'stores' => $this->when(isset($this->managed_stores), fn () => $this->managed_stores),
            'last_login_at' => $this->last_login_at,
            'created_at' => $this->created_at,
        ];
    }
}
