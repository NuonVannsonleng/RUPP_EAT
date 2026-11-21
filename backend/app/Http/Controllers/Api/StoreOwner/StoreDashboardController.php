<?php

namespace App\Http\Controllers\Api\StoreOwner;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Http\Resources\StoreResource;
use App\Models\Order;
use App\Models\Store;
use App\Services\ReportService;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Store owner / staff analytics. Every query is scoped to stores the user manages. */
class StoreDashboardController extends Controller
{
    public function __construct(private ReportService $reports) {}

    /** GET /api/store/stores — stores this user can manage. */
    public function myStores(Request $request): JsonResponse
    {
        $stores = Store::whereIn('id', $request->user()->managedStoreIds())->with('building')->orderBy('name')->get();

        return $this->ok(StoreResource::collection($stores));
    }

    /** GET /api/store/dashboard?store_id= */
    public function dashboard(Request $request): JsonResponse
    {
        $storeIds = $this->scope($request);
        $today = [CarbonImmutable::today(), CarbonImmutable::now()->endOfDay()];
        $orders = fn () => Order::whereIn('store_id', $storeIds);

        $todaySummary = $this->reports->summary($storeIds, ...$today);
        [$weekFrom, $weekTo] = [CarbonImmutable::today()->subDays(6), CarbonImmutable::now()->endOfDay()];

        return $this->ok([
            'today' => [
                'orders' => $todaySummary['total_orders'],
                'completed' => $todaySummary['completed_orders'],
                'cancelled' => $todaySummary['cancelled_orders'],
                'sales' => $todaySummary['revenue'],
            ],
            'pending' => $orders()->where('status', 'pending')->count(),
            'in_progress' => $orders()->whereIn('status', ['accepted', 'preparing'])->count(),
            'ready' => $orders()->whereIn('status', ['ready', 'driver_assigned'])->count(),
            'out_for_delivery' => $orders()->where('status', 'on_the_way')->count(),
            'sales_last_7_days' => $this->reports->revenueSeries($storeIds, $weekFrom, $weekTo, 'daily'),
            'popular_products' => $this->reports->bestSellers($storeIds, CarbonImmutable::today()->subDays(29), $weekTo, 5),
            'recent_orders' => OrderResource::collection(
                $orders()->with(['customer', 'items.product', 'delivery', 'driver', 'store'])->latest()->limit(8)->get()
            )->resolve($request),
        ]);
    }

    /** GET /api/store/reports?store_id=&period=daily|weekly|monthly&from=&to= */
    public function reports(Request $request): JsonResponse
    {
        $request->validate([
            'period' => ['nullable', 'in:daily,weekly,monthly'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
        ]);
        $storeIds = $this->scope($request);
        $period = $request->input('period', 'daily');
        [$from, $to] = $this->reports->range($period, $request->from, $request->to);

        return $this->ok([
            'range' => ['from' => $from->toDateString(), 'to' => $to->toDateString(), 'period' => $period],
            'summary' => $this->reports->summary($storeIds, $from, $to),
            'revenue' => $this->reports->revenueSeries($storeIds, $from, $to, $period),
            'best_sellers' => $this->reports->bestSellers($storeIds, $from, $to),
            'status_breakdown' => $this->reports->statusBreakdown($storeIds, $from, $to),
            'fulfillment_split' => $this->reports->fulfillmentSplit($storeIds, $from, $to),
        ]);
    }

    /** Restrict to one managed store (store_id) or all of them. */
    private function scope(Request $request): array
    {
        $ids = $request->user()->managedStoreIds();
        if ($request->store_id) {
            abort_unless(in_array($request->store_id, $ids, true), 403, 'You do not manage this store.');

            return [$request->store_id];
        }

        return $ids;
    }
}
