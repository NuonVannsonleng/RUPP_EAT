<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

/**
 * Driver self-registration. The account starts as "pending" and cannot go online
 * until an administrator verifies it in the dashboard (Drivers page).
 */
class RegisterDriverRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email:rfc', 'max:150', 'unique:users,email'],
            'phone' => ['required', 'string', 'regex:/^\+?[0-9 ]{8,15}$/'],
            'university_id' => ['nullable', 'string', 'max:50', 'regex:/^[A-Za-z0-9\-\/]+$/', 'unique:users,university_id'],
            'vehicle_type' => ['required', 'in:motorbike,bicycle,walking'],
            'plate_number' => ['required_if:vehicle_type,motorbike', 'nullable', 'string', 'max:30'],
            'national_id' => ['required', 'string', 'max:50'],
            'password' => ['required', 'confirmed', Password::min(8)->letters()->numbers()],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }

    public function messages(): array
    {
        return [
            'plate_number.required_if' => 'Enter your motorbike plate number.',
            'national_id.required' => 'Enter your national ID or student / staff ID card number for verification.',
            'phone.regex' => 'Please enter a valid phone number.',
        ];
    }
}
