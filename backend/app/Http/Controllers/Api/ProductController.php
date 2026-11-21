<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Models\Store;
use App\Services\ActivityLogger;
use App\Support\Media;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ProductController extends Controller
{
    /** GET /api/products?search=&category=&store_id=&sort=popular|price_asc|price_desc|newest|rating */
    public function index(Request $request): JsonResponse
    {
        $products = $this->filtered(Product::query()->whereHas('store', fn ($q) => $q->where('status', 'active')), $request)
            ->with(['category', 'store'])
            ->paginate($this->perPage(20));

        return $this->ok(ProductResource::collection($products));
    }

    /** GET /api/stores/{store}/products — full menu of one store. */
    public function forStore(Request $request, Store $store): JsonResponse
    {
        $canManage = $request->user()?->canManageStore($store);
        abort_if($store->status !== 'active' && ! $canManage, 404);

        $products = $this->filtered($store->products()->getQuery(), $request)
            ->with('category')
            ->paginate($this->perPage(100));

        return $this->ok(ProductResource::collection($products));
    }

    public function show(Product $product): JsonResponse
    {
        return $this->ok(new ProductResource($product->load(['category', 'store'])));
    }

    /** POST /api/products — store owner adds a product to their store. */
    public function store(ProductRequest $request): JsonResponse
    {
        $user = $request->user();
        $storeId = $request->store_id ?? (count($ids = $user->managedStoreIds()) === 1 ? $ids[0] : null);

        if (! $storeId) {
            throw ValidationException::withMessages(['store_id' => 'Choose which store this product belongs to.']);
        }
        abort_unless($user->canManageStore($storeId), 403, 'You can only add products to your own store.');

        $data = $request->safe()->except(['image', 'remove_image', 'store_id']);
        $data['store_id'] = $storeId;
        if ($request->hasFile('image')) {
            $data['image_path'] = Media::store($request->file('image'), 'products');
        }

        $product = Product::create($data);
        ActivityLogger::log('product.created', "Product {$product->name} added", $product);

        return $this->created(new ProductResource($product->load('category')), 'Product added.');
    }

    /** PUT /api/products/{id} (use POST + _method=PUT when uploading an image). */
    public function update(ProductRequest $request, Product $product): JsonResponse
    {
        $this->authorize('update', $product);

        $data = $request->safe()->except(['image', 'remove_image', 'store_id']);
        if ($request->hasFile('image')) {
            $data['image_path'] = Media::replace($product->image_path, $request->file('image'), 'products');
        } elseif ($request->boolean('remove_image')) {
            Media::delete($product->image_path);
            $data['image_path'] = null;
        }

        $product->update($data);
        ActivityLogger::log('product.updated', "Product {$product->name} updated", $product, array_keys($data));

        return $this->ok(new ProductResource($product->fresh('category')), 'Product updated.');
    }

    /** DELETE /api/products/{id} — soft delete keeps order history intact. */
    public function destroy(Product $product): JsonResponse
    {
        $this->authorize('delete', $product);
        $product->delete();
        ActivityLogger::log('product.deleted', "Product {$product->name} deleted", $product);

        return $this->ok(null, 'Product deleted.');
    }

    private function filtered(Builder $query, Request $request): Builder
    {
        $manage = $request->boolean('manage'); // dashboard view: include unavailable items

        return $query
            ->when(! $manage, fn ($q) => $q->where('is_available', true))
            ->when($request->search, fn ($q, $s) => $q->where(fn ($w) => $w
                ->where('products.name', 'ilike', "%$s%")->orWhere('products.description', 'ilike', "%$s%")))
            ->when($request->category, fn ($q, $c) => Str::isUuid($c)
                ? $q->where('category_id', $c)
                : $q->whereHas('category', fn ($cat) => $cat->where('slug', $c)))
            ->when($request->store_id, fn ($q, $id) => $q->where('store_id', $id))
            ->when($request->availability === 'unavailable', fn ($q) => $q->where('is_available', false))
            ->when($request->availability === 'low_stock', fn ($q) => $q->whereNotNull('stock_quantity')->where('stock_quantity', '<=', 5))
            ->when($request->sort, function ($q, $sort) {
                return match ($sort) {
                    'price_asc' => $q->orderBy('price'),
                    'price_desc' => $q->orderByDesc('price'),
                    'newest' => $q->latest(),
                    'rating' => $q->orderByDesc('rating_avg'),
                    'name' => $q->orderBy('name'),
                    default => $q->orderByDesc('sold_count'),
                };
            }, fn ($q) => $q->orderBy('category_id')->orderBy('name'));
    }
}
