<?php

namespace App\Models;

use App\Enums\RoleName;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, HasUuids, Notifiable, SoftDeletes;

    protected $fillable = [
        'role_id', 'name', 'email', 'university_id', 'user_type', 'phone',
        'avatar_path', 'status', 'fcm_token', 'password', 'last_login_at',
    ];

    protected $hidden = ['password', 'remember_token', 'fcm_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }

    public function driverProfile(): HasOne
    {
        return $this->hasOne(DriverProfile::class);
    }

    /** Stores this user owns. */
    public function ownedStores(): HasMany
    {
        return $this->hasMany(Store::class, 'owner_id');
    }

    /** Stores this user works at as staff. */
    public function staffStores(): BelongsToMany
    {
        return $this->belongsToMany(Store::class, 'store_staff')->withTimestamps();
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'customer_id');
    }

    public function cart(): HasOne
    {
        return $this->hasOne(Cart::class);
    }

    public function favorites(): BelongsToMany
    {
        return $this->belongsToMany(Store::class, 'favorites')->withTimestamps();
    }

    public function appNotifications(): HasMany
    {
        return $this->hasMany(AppNotification::class);
    }

    public function hasRole(RoleName|string ...$roles): bool
    {
        $name = $this->role?->name;
        foreach ($roles as $role) {
            if ($name === ($role instanceof RoleName ? $role->value : $role)) {
                return true;
            }
        }

        return false;
    }

    public function isAdmin(): bool
    {
        return $this->hasRole(RoleName::Admin);
    }

    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    /** IDs of every store this user can manage (owner or staff). */
    public function managedStoreIds(): array
    {
        return $this->managedStoreIdsCache ??= Store::query()
            ->where('owner_id', $this->id)
            ->orWhereHas('staff', fn ($q) => $q->where('users.id', $this->id))
            ->pluck('id')
            ->all();
    }

    /** Per-request memo for managedStoreIds(). */
    private ?array $managedStoreIdsCache = null;

    public function canManageStore(Store|string $store): bool
    {
        $id = $store instanceof Store ? $store->id : $store;

        return $this->isAdmin() || in_array($id, $this->managedStoreIds(), true);
    }
}
