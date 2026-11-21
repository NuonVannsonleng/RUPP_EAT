<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ReviewResource;
use App\Http\Resources\StoreResource;
use App\Models\AppNotification;
use App\Models\Order;
use App\Models\Product;
use App\Models\Review;
use App\Models\Store;
use App\Models\SupportTicket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Favorites, reviews, notifications inbox and support tickets. */
class CustomerController extends Controller
{
    // ---------- Favorites ----------

    public function favorites(Request $request): JsonResponse
    {
        $stores = $request->user()->favorites()->with('building')->where('status', 'active')->get()
            ->each(fn ($s) => $s->is_favorite = true);

        return $this->ok(StoreResource::collection($stores));
    }

    /** POST /api/favorites/{store} toggles. */
    public function toggleFavorite(Request $request, Store $store): JsonResponse
    {
        $result = $request->user()->favorites()->toggle($store->id);
        $isFavorite = ! empty($result['attached']);

        return $this->ok(['store_id' => $store->id, 'is_favorite' => $isFavorite],
            $isFavorite ? 'Added to favorites.' : 'Removed from favorites.');
    }

    // ---------- Reviews ----------

    public function storeReviews(Store $store): JsonResponse
    {
        $reviews = $store->reviews()->with(['user', 'product'])->latest()->paginate($this->perPage(20));

        return $this->ok(ReviewResource::collection($reviews));
    }

    public function productReviews(Product $product): JsonResponse
    {
        $reviews = $product->reviews()->with('user')->latest()->paginate($this->perPage(20));

        return $this->ok(ReviewResource::collection($reviews));
    }

    /**
     * POST /api/orders/{order}/reviews
     * { rating, comment?, products?: [{product_id, rating, comment?}] }
     * Only for the customer's own completed orders; one review per order (+ per product).
     */
    public function review(Request $request, Order $order): JsonResponse
    {
        abort_unless($order->customer_id === $request->user()->id, 404);
        if (! $order->status->isCompleted()) {
            throw ValidationException::withMessages(['order' => 'You can review an order after it is completed.']);
        }

        $data = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:1000'],
            'products' => ['sometimes', 'array', 'max:30'],
            'products.*.product_id' => ['required', 'uuid'],
            'products.*.rating' => ['required', 'integer', 'between:1,5'],
            'products.*.comment' => ['nullable', 'string', 'max:500'],
        ]);

        if ($order->reviews()->whereNull('product_id')->exists()) {
            throw ValidationException::withMessages(['order' => 'You already reviewed this order.']);
        }

        $orderedProductIds = $order->items()->pluck('product_id')->filter()->all();

        DB::transaction(function () use ($order, $data, $request, $orderedProductIds) {
            Review::create([
                'user_id' => $request->user()->id, 'order_id' => $order->id, 'store_id' => $order->store_id,
                'rating' => $data['rating'], 'comment' => $data['comment'] ?? null,
            ]);
            foreach ($data['products'] ?? [] as $p) {
                if (! in_array($p['product_id'], $orderedProductIds, true)) {
                    continue; // only products that were in this order
                }
                Review::create([
                    'user_id' => $request->user()->id, 'order_id' => $order->id, 'store_id' => $order->store_id,
                    'product_id' => $p['product_id'], 'rating' => $p['rating'], 'comment' => $p['comment'] ?? null,
                ]);
                $this->refreshRating(Product::withTrashed()->find($p['product_id']), 'product_id');
            }
            $this->refreshRating($order->store, 'store_id', true);
        });

        return $this->created(null, 'Thank you for your review!');
    }

    private function refreshRating($model, string $column, bool $storeLevel = false): void
    {
        if (! $model) {
            return;
        }
        $stats = Review::where($column, $model->id)
            ->when($storeLevel, fn ($q) => $q->whereNull('product_id'))
            ->selectRaw('AVG(rating) as avg, COUNT(*) as cnt')->first();
        $model->forceFill(['rating_avg' => round((float) $stats->avg, 2), 'rating_count' => (int) $stats->cnt])->save();
    }

    // ---------- Notifications ----------

    public function notifications(Request $request): JsonResponse
    {
        $items = AppNotification::where('user_id', $request->user()->id)->latest()->paginate($this->perPage(30));
        $unread = AppNotification::where('user_id', $request->user()->id)->whereNull('read_at')->count();

        return $this->paged($items, ['unread_count' => $unread]);
    }

    public function unreadCount(Request $request): JsonResponse
    {
        return $this->ok(['unread_count' => AppNotification::where('user_id', $request->user()->id)->whereNull('read_at')->count()]);
    }

    public function markRead(Request $request, AppNotification $notification): JsonResponse
    {
        abort_unless($notification->user_id === $request->user()->id, 404);
        $notification->update(['read_at' => now()]);

        return $this->ok(null);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        AppNotification::where('user_id', $request->user()->id)->whereNull('read_at')->update(['read_at' => now()]);

        return $this->ok(null, 'All notifications marked as read.');
    }

    // ---------- Support ----------

    public function supportTickets(Request $request): JsonResponse
    {
        return $this->ok(SupportTicket::where('user_id', $request->user()->id)->with('order:id,order_number')->latest()->get());
    }

    public function createSupportTicket(Request $request): JsonResponse
    {
        $data = $request->validate([
            'subject' => ['required', 'string', 'max:150'],
            'message' => ['required', 'string', 'max:2000'],
            'order_id' => ['nullable', 'uuid', 'exists:orders,id'],
        ]);
        if (! empty($data['order_id'])) {
            $order = Order::findOrFail($data['order_id']);
            abort_unless(in_array($request->user()->id, [$order->customer_id, $order->driver_id], true), 403);
        }

        $ticket = SupportTicket::create($data + ['user_id' => $request->user()->id]);

        return $this->created($ticket, 'Support request sent. Our team will contact you soon.');
    }
}
