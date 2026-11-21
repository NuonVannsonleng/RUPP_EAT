<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\OrderResource;
use App\Http\Resources\ProductResource;
use App\Http\Resources\StoreResource;
use App\Models\Announcement;
use App\Models\Faculty;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\ProductCategory;
use App\Models\Store;
use App\Models\SystemSetting;
use App\Support\Media;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Read-only data the mobile app needs: home feed, categories, campus locations, settings. */
class CatalogController extends Controller
{
    /** GET /api/home — everything the customer home screen shows, in one request. */
    public function home(Request $request): JsonResponse
    {
        $user = $request->user();

        $featured = Store::active()->with('building')->where('is_featured', true)
            ->orderByDesc('rating_avg')->limit(8)->get();
        if ($featured->isEmpty()) {
            $featured = Store::active()->with('building')->orderByDesc('rating_avg')->limit(8)->get();
        }

        $popular = Product::with(['store', 'category'])->where('is_available', true)
            ->whereHas('store', fn ($q) => $q->where('status', 'active'))
            ->orderByDesc('sold_count')->limit(10)->get();

        // Most recently ordered distinct products by this customer.
        $recentIds = OrderItem::query()
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->where('orders.customer_id', $user->id)
            ->whereNotNull('order_items.product_id')
            ->groupBy('order_items.product_id')
            ->orderByRaw('MAX(orders.created_at) DESC')
            ->limit(8)
            ->pluck('order_items.product_id');
        $recent = Product::with(['store', 'category'])->whereIn('id', $recentIds)->get()
            ->sortBy(fn ($p) => $recentIds->search($p->id))->values();

        $active = Order::where('customer_id', $user->id)
            ->whereIn('status', ['pending', 'accepted', 'preparing', 'ready', 'driver_assigned', 'on_the_way'])
            ->with('store')->latest()->limit(3)->get();

        return $this->ok([
            'categories' => CategoryResource::collection(ProductCategory::where('is_active', true)->orderBy('sort_order')->get())->resolve($request),
            'featured_stores' => StoreResource::collection($featured)->resolve($request),
            'popular_products' => ProductResource::collection($popular)->resolve($request),
            'recent_products' => ProductResource::collection($recent)->resolve($request),
            'active_orders' => OrderResource::collection($active)->resolve($request),
            'announcements' => $this->announcementsFor('customers'),
        ]);
    }

    public function categories(Request $request): JsonResponse
    {
        $categories = ProductCategory::where('is_active', true)->orderBy('sort_order')->get();

        return $this->ok(CategoryResource::collection($categories));
    }

    public function announcements(Request $request): JsonResponse
    {
        $audience = match ($request->user()->role->name) {
            'driver' => 'drivers',
            'store_owner' => 'stores',
            default => 'customers',
        };

        return $this->ok($this->announcementsFor($audience));
    }

    /** GET /api/campus/locations — faculty → building → floor → classroom tree for checkout. */
    public function campus(): JsonResponse
    {
        $faculties = Faculty::where('is_active', true)
            ->with(['buildings' => fn ($q) => $q->where('is_active', true)->orderBy('name'),
                'buildings.floors.classrooms' => fn ($q) => $q->where('is_deliverable', true)])
            ->orderBy('name')
            ->get();

        return $this->ok($faculties->map(fn ($f) => [
            'id' => $f->id,
            'name' => $f->name,
            'code' => $f->code,
            'buildings' => $f->buildings->map(fn ($b) => [
                'id' => $b->id,
                'name' => $b->name,
                'code' => $b->code,
                'floors' => $b->floors->map(fn ($fl) => [
                    'id' => $fl->id,
                    'number' => $fl->number,
                    'label' => $fl->label ?? 'Floor '.$fl->number,
                    'classrooms' => $fl->classrooms->map(fn ($c) => ['id' => $c->id, 'name' => $c->name, 'type' => $c->type])->values(),
                ])->filter(fn ($fl) => $fl['classrooms']->isNotEmpty())->values(),
            ])->values(),
        ]));
    }

    /** GET /api/settings/public — fees and toggles the apps need to render checkout. */
    public function publicSettings(): JsonResponse
    {
        return $this->ok([
            'delivery_fee' => (float) SystemSetting::get('delivery_fee', 0.5),
            'free_delivery_threshold' => (float) SystemSetting::get('free_delivery_threshold', 0),
            'min_order_amount' => (float) SystemSetting::get('min_order_amount', 0),
            'delivery_enabled' => (bool) SystemSetting::get('delivery_enabled', true),
            'khqr_enabled' => (bool) config('services.khqr.enabled'),
            'support_phone' => SystemSetting::get('support_phone'),
            'support_email' => SystemSetting::get('support_email'),
            'currency' => 'USD',
        ]);
    }

    private function announcementsFor(string $audience): array
    {
        return Announcement::visibleTo($audience)->latest()->limit(10)->get()->map(fn ($a) => [
            'id' => $a->id,
            'title' => $a->title,
            'body' => $a->body,
            'type' => $a->type,
            'image_url' => Media::url($a->image_path),
            'store_id' => $a->store_id,
            'created_at' => $a->created_at,
        ])->all();
    }
}
