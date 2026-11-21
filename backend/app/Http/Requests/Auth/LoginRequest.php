<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'login' => ['required', 'string', 'max:150'], // email OR student/staff ID
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:100'],
            'app' => ['nullable', 'in:mobile,dashboard'],
        ];
    }

    public function messages(): array
    {
        return ['login.required' => 'Enter your email or student / staff ID.'];
    }
}
