<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Items and prices come from the server-side cart, never from the client.
 * Send header "Idempotency-Key: <uuid>" to make retries safe.
 */
class PlaceOrderRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'fulfillment_method' => ['required', 'in:delivery,pickup'],
            'payment_method' => ['required', 'in:cash_on_delivery,cash_on_pickup,khqr'],
            'classroom_id' => ['required_if:fulfillment_method,delivery', 'nullable', 'uuid', 'exists:classrooms,id'],
            'delivery_instructions' => ['nullable', 'string', 'max:300'],
            'customer_note' => ['nullable', 'string', 'max:300'],
        ];
    }

    public function messages(): array
    {
        return ['classroom_id.required_if' => 'Please choose the classroom to deliver to.'];
    }
}
