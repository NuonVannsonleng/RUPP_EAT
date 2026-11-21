<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

class SystemSetting extends Model
{
    use HasUuids;

    protected $fillable = ['key', 'value', 'type', 'group', 'description'];

    protected static function booted(): void
    {
        static::saved(fn () => Cache::forget('system_settings'));
        static::deleted(fn () => Cache::forget('system_settings'));
    }

    /** Typed value of a setting, cached. */
    public static function get(string $key, mixed $default = null): mixed
    {
        $all = Cache::rememberForever('system_settings', fn () => static::all()->keyBy('key'));
        $setting = $all->get($key);

        return $setting ? $setting->typedValue() : $default;
    }

    public function typedValue(): mixed
    {
        return match ($this->type) {
            'number' => is_numeric($this->value) ? $this->value + 0 : 0,
            'boolean' => filter_var($this->value, FILTER_VALIDATE_BOOLEAN),
            'json' => json_decode($this->value ?? 'null', true),
            default => $this->value,
        };
    }
}
