<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreRequest;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\StoreResource;
use App\Models\ProductCategory;
use App\Models\Store;
use App\Models\User;
use App\Services\ActivityLogger;
use App\Support\Media;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class StoreController extends Controller
{
    /** GET /api/stores?search=&category=&featured=1&open_now=1&sort=rating|popular|name */
    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()?->id;

        $favoriteIds = DB::table('favorites')->where('user_id', $userId)->select('store_id');

        $stores = Store::query()
            ->active()
            ->select('stores.*')
            ->with('building')
            ->withCount(['products' => fn ($q) => $q->where('is_available', true)])
            ->when($userId, fn ($q) => $q->selectRaw('stores.id IN ('.$favoriteIds->toSql().') as is_favorite', $favoriteIds->getBindings()))
            ->when($request->search, fn ($q, $s) => $q->where(fn ($w) => $w
                ->where('name', 'ilike', "%$s%")
                ->orWhere('description', 'ilike', "%$s%")
                ->orWhereHas('products', fn ($p) => $p->where('name', 'ilike', "%$s%"))))
            ->when($request->category, fn ($q, $c) => $q->whereHas('products', fn ($p) => $p
                ->whereHas('category', fn ($cat) => Str::isUuid($c) ? $cat->whereKey($c) : $cat->where('slug', $c))))
            ->when($request->boolean('featured'), fn ($q) => $q->where('is_featured', true))
            ->when($request->boolean('favorites') && $userId, fn ($q) => $q->whereIn('stores.id', $favoriteIds))
            ->when($request->sort === 'popular', fn ($q) => $q->withCount('orders')->orderByDesc('orders_count'))
            ->when($request->sort === 'name', fn ($q) => $q->orderBy('name'))
            ->when(! in_array($request->sort, ['popular', 'name']), fn ($q) => $q->orderByDesc('is_featured')->orderByDesc('rating_avg'))
            ->paginate($this->perPage(20));

        if ($request->boolean('open_now')) {
            $stores->setCollection($stores->getCollection()->filter->isAcceptingOrders()->values());
        }

        return $this->ok(StoreResource::collection($stores));
    }

    /** GET /api/stores/{id} — store profile plus the categories it sells. */
    public function show(Request $request, Store $store): JsonResponse
    {
        abort_if($store->status !== 'active' && ! $request->user()?->canManageStore($store), 404);

        $store->load('building', 'owner')->loadCount(['products' => fn ($q) => $q->where('is_available', true)]);
        $store->is_favorite = $request->user()
            ? $request->user()->favorites()->where('stores.id', $store->id)->exists()
            : false;

        $categories = ProductCategory::whereHas('products', fn ($q) => $q->where('store_id', $store->id))
            ->orderBy('sort_order')->get();

        return $this->ok([
            'store' => (new StoreResource($store))->resolve($request),
            'categories' => CategoryResource::collection($categories)->resolve($request),
            'pickup_location' => trim(($store->building?->name ?? 'RUPP campus').($store->location_note ? ' – '.$store->location_note : '')),
        ]);
    }

    /** POST /api/stores — admin registers a store for an owner account. */
    public function store(StoreRequest $request): JsonResponse
    {
        $this->authorize('create', Store::class);

        $owner = User::with('role')->findOrFail($request->owner_id);
        if (! $owner->hasRole('store_owner')) {
            throw ValidationException::withMessages(['owner_id' => 'The owner must have the Store Owner role.']);
        }

        $data = $request->safe()->except(['logo', 'cover']);
        $data['slug'] = $this->uniqueSlug($data['name']);
        $data['status'] = $data['status'] ?? 'active';
        if ($request->hasFile('logo')) {
            $data['logo_path'] = Media::store($request->file('logo'), 'stores');
        }
        if ($request->hasFile('cover')) {
            $data['cover_path'] = Media::store($request->file('cover'), 'stores');
        }

        $store = Store::create($data);
        ActivityLogger::log('store.created', "Store {$store->name} registered", $store);

        return $this->created(new StoreResource($store->load('building', 'owner')), 'Store created.');
    }

    /** PUT /api/stores/{id} — owner edits own store, admin edits any. */
    public function update(StoreRequest $request, Store $store): JsonResponse
    {
        $this->authorize('update', $store);

        $data = $request->safe()->except(['logo', 'cover']);
        if (isset($data['name']) && $data['name'] !== $store->name) {
            $data['slug'] = $this->uniqueSlug($data['name'], $store->id);
        }
        if ($request->hasFile('logo')) {
            $data['logo_path'] = Media::replace($store->logo_path, $request->file('logo'), 'stores');
        }
        if ($request->hasFile('cover')) {
            $data['cover_path'] = Media::replace($store->cover_path, $request->file('cover'), 'stores');
        }

        $store->update($data);
        ActivityLogger::log('store.updated', "Store {$store->name} updated", $store, array_keys($data));

        return $this->ok(new StoreResource($store->fresh(['building', 'owner'])), 'Store updated.');
    }

    private function uniqueSlug(string $name, ?string $ignoreId = null): string
    {
        $base = Str::slug($name) ?: 'store';
        $slug = $base;
        $i = 2;
        while (Store::withTrashed()->where('slug', $slug)->when($ignoreId, fn ($q) => $q->where('id', '!=', $ignoreId))->exists()) {
            $slug = $base.'-'.$i++;
        }

        return $slug;
    }
}
