<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateOrderStatusRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'status' => ['required', 'in:accepted,preparing,ready,picked_up,rejected,cancelled'],
            'reason' => ['nullable', 'string', 'max:255'],
            'note' => ['nullable', 'string', 'max:255'],
            'pickup_code' => ['required_if:status,picked_up', 'nullable', 'string', 'size:4'],
        ];
    }
}
