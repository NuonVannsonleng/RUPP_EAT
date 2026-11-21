<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    public function rules(): array
    {
        $id = $this->user()->id;

        return [
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'email' => ['sometimes', 'required', 'email:rfc', 'max:150', Rule::unique('users', 'email')->ignore($id)],
            'phone' => ['sometimes', 'required', 'string', 'regex:/^\+?[0-9 ]{8,15}$/'],
            'avatar' => ['sometimes', 'image', 'max:2048'],
            'vehicle_type' => ['sometimes', 'in:motorbike,bicycle,walking'],
            'plate_number' => ['sometimes', 'nullable', 'string', 'max:30'],
        ];
    }
}
