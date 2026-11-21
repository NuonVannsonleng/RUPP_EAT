<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/** Create (admin) or update (admin / store owner) a store profile. */
class StoreRequest extends FormRequest
{
    public function rules(): array
    {
        $creating = $this->isMethod('post') && ! $this->route('store');
        $req = $creating ? 'required' : 'sometimes';
        $admin = $this->user()?->isAdmin();

        return [
            'owner_id' => [$creating ? 'required' : 'sometimes', $admin ? 'uuid' : 'prohibited', 'exists:users,id'],
            'name' => [$req, 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:1000'],
            'building_id' => ['nullable', 'uuid', 'exists:buildings,id'],
            'location_note' => ['nullable', 'string', 'max:200'],
            'phone' => ['nullable', 'string', 'regex:/^\+?[0-9 ]{8,15}$/'],
            'opening_time' => [$req, 'date_format:H:i'],
            'closing_time' => [$req, 'date_format:H:i'],
            'is_open' => ['sometimes', 'boolean'],
            'status' => [$admin ? 'sometimes' : 'prohibited', 'in:active,suspended'],
            'is_featured' => [$admin ? 'sometimes' : 'prohibited', 'boolean'],
            'logo' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
            'cover' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
        ];
    }

    protected function prepareForValidation(): void
    {
        foreach (['is_open', 'is_featured'] as $key) {
            if ($this->has($key)) {
                $this->merge([$key => filter_var($this->input($key), FILTER_VALIDATE_BOOLEAN)]);
            }
        }
        // Accept "07:00:00" from clients too.
        foreach (['opening_time', 'closing_time'] as $key) {
            if (is_string($this->input($key)) && strlen($this->input($key)) === 8) {
                $this->merge([$key => substr($this->input($key), 0, 5)]);
            }
        }
    }
}
