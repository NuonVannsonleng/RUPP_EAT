<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/** Create (POST) and update (PUT/PATCH) a product. Multipart when uploading an image. */
class ProductRequest extends FormRequest
{
    public function rules(): array
    {
        $creating = $this->isMethod('post') && ! $this->route('product');
        $req = $creating ? 'required' : 'sometimes';

        return [
            'store_id' => [$creating ? 'nullable' : 'prohibited', 'uuid', 'exists:stores,id'],
            'category_id' => ['nullable', 'uuid', 'exists:product_categories,id'],
            'name' => [$req, 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:1000'],
            'price' => [$req, 'numeric', 'min:0.01', 'max:1000', 'decimal:0,2'],
            'stock_quantity' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'is_available' => ['sometimes', 'boolean'],
            'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
            'remove_image' => ['sometimes', 'boolean'],
        ];
    }

    protected function prepareForValidation(): void
    {
        // Multipart forms send booleans/empty values as strings.
        foreach (['is_available', 'remove_image'] as $key) {
            if ($this->has($key)) {
                $this->merge([$key => filter_var($this->input($key), FILTER_VALIDATE_BOOLEAN)]);
            }
        }
        if ($this->input('stock_quantity') === '' ) {
            $this->merge(['stock_quantity' => null]);
        }
        if ($this->input('category_id') === '') {
            $this->merge(['category_id' => null]);
        }
    }
}
