<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

/** Self-registration is for customers (students / lecturers / staff) only. */
class RegisterRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email:rfc', 'max:150', 'unique:users,email'],
            'university_id' => ['required', 'string', 'max:50', 'regex:/^[A-Za-z0-9\-\/]+$/', 'unique:users,university_id'],
            'user_type' => ['required', 'in:student,lecturer,staff'],
            'phone' => ['required', 'string', 'regex:/^\+?[0-9 ]{8,15}$/'],
            'password' => ['required', 'confirmed', Password::min(8)->letters()->numbers()],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }

    public function messages(): array
    {
        return [
            'university_id.unique' => 'This student / staff ID is already registered.',
            'phone.regex' => 'Please enter a valid phone number.',
        ];
    }
}
