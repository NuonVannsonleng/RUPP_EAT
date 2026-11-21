<?php

namespace App\Services;

use App\Models\Order;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

/**
 * Sales analytics. Revenue counts only COMPLETED orders (delivered / picked up),
 * i.e. money actually collected. Pass $storeIds = null for platform-wide reports.
 */
class ReportService
{
    private const COMPLETED = ['delivered', 'picked_up'];

    public function range(?string $period, ?string $from, ?string $to): array
    {
        $end = $to ? CarbonImmutable::parse($to)->endOfDay() : CarbonImmutable::now()->endOfDay();
        $start = $from ? CarbonImmutable::parse($from)->startOfDay() : match ($period) {
            'daily' => $end->subDays(13)->startOfDay(),
            'monthly' => $end->subMonths(11)->startOfMonth(),
            default => $end->subWeeks(11)->startOfWeek(),
        };

        return [$start, $end];
    }

    public function summary(?array $storeIds, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $base = $this->orders($storeIds)->whereBetween('created_at', [$from, $to]);
        $completed = (clone $base)->whereIn('status', self::COMPLETED);

        $revenue = (float) (clone $completed)->sum('total');
        $count = (clone $completed)->count();

        return [
            'total_orders' => (clone $base)->count(),
            'completed_orders' => $count,
            'cancelled_orders' => (clone $base)->whereIn('status', ['cancelled', 'rejected'])->count(),
            'revenue' => round($revenue, 2),
            'food_sales' => round((float) (clone $completed)->sum('subtotal'), 2),
            'delivery_fees' => round((float) (clone $completed)->sum('delivery_fee'), 2),
            'average_order_value' => $count ? round($revenue / $count, 2) : 0,
        ];
    }

    /** Revenue + order count per day/week/month, with empty periods filled in. */
    public function revenueSeries(?array $storeIds, CarbonImmutable $from, CarbonImmutable $to, string $period = 'daily'): array
    {
        $unit = ['daily' => 'day', 'weekly' => 'week', 'monthly' => 'month'][$period] ?? 'day';

        $rows = $this->orders($storeIds)
            ->whereIn('status', self::COMPLETED)
            ->whereBetween('created_at', [$from, $to])
            ->selectRaw("date_trunc('$unit', created_at)::date as bucket, SUM(total) as revenue, COUNT(*) as orders")
            ->groupBy('bucket')
            ->get()
            ->keyBy(fn ($r) => (string) $r->bucket);

        $series = [];
        $cursor = match ($unit) {
            'week' => $from->startOfWeek(),
            'month' => $from->startOfMonth(),
            default => $from->startOfDay(),
        };
        while ($cursor <= $to) {
            $key = $cursor->toDateString();
            $series[] = [
                'period' => $key,
                'label' => match ($unit) {
                    'month' => $cursor->format('M Y'),
                    'week' => 'Wk '.$cursor->format('d M'),
                    default => $cursor->format('d M'),
                },
                'revenue' => round((float) ($rows[$key]->revenue ?? 0), 2),
                'orders' => (int) ($rows[$key]->orders ?? 0),
            ];
            $cursor = $cursor->add(1, $unit);
        }

        return $series;
    }

    public function bestSellers(?array $storeIds, CarbonImmutable $from, CarbonImmutable $to, int $limit = 10): array
    {
        return DB::table('order_items')
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->join('stores', 'stores.id', '=', 'orders.store_id')
            ->whereIn('orders.status', self::COMPLETED)
            ->whereBetween('orders.created_at', [$from, $to])
            ->when($storeIds !== null, fn ($q) => $q->whereIn('orders.store_id', $storeIds))
            ->groupBy('order_items.product_id', 'order_items.product_name', 'stores.name')
            ->selectRaw('order_items.product_id, order_items.product_name as name, stores.name as store_name,
                         SUM(order_items.quantity) as quantity, SUM(order_items.line_total) as revenue')
            ->orderByDesc('quantity')
            ->limit($limit)
            ->get()
            ->map(fn ($r) => [
                'product_id' => $r->product_id,
                'name' => $r->name,
                'store_name' => $r->store_name,
                'quantity' => (int) $r->quantity,
                'revenue' => round((float) $r->revenue, 2),
            ])->all();
    }

    public function statusBreakdown(?array $storeIds, CarbonImmutable $from, CarbonImmutable $to): array
    {
        return $this->orders($storeIds)->whereBetween('created_at', [$from, $to])
            ->selectRaw('status, COUNT(*) as count')->groupBy('status')->pluck('count', 'status')
            ->map(fn ($c) => (int) $c)->all();
    }

    public function fulfillmentSplit(?array $storeIds, CarbonImmutable $from, CarbonImmutable $to): array
    {
        return $this->orders($storeIds)->whereBetween('created_at', [$from, $to])
            ->selectRaw('fulfillment_method, COUNT(*) as count')->groupBy('fulfillment_method')
            ->pluck('count', 'fulfillment_method')->map(fn ($c) => (int) $c)->all();
    }

    public function revenueByStore(CarbonImmutable $from, CarbonImmutable $to): array
    {
        return DB::table('orders')
            ->join('stores', 'stores.id', '=', 'orders.store_id')
            ->whereIn('orders.status', self::COMPLETED)
            ->whereBetween('orders.created_at', [$from, $to])
            ->groupBy('stores.id', 'stores.name')
            ->selectRaw('stores.id, stores.name, COUNT(*) as orders, SUM(orders.total) as revenue')
            ->orderByDesc('revenue')
            ->get()
            ->map(fn ($r) => ['store_id' => $r->id, 'name' => $r->name, 'orders' => (int) $r->orders, 'revenue' => round((float) $r->revenue, 2)])
            ->all();
    }

    public function driverPerformance(CarbonImmutable $from, CarbonImmutable $to): array
    {
        return DB::table('deliveries')
            ->join('users', 'users.id', '=', 'deliveries.driver_id')
            ->join('orders', 'orders.id', '=', 'deliveries.order_id')
            ->whereBetween('deliveries.created_at', [$from, $to])
            ->groupBy('users.id', 'users.name')
            ->selectRaw("users.id, users.name,
                COUNT(*) FILTER (WHERE deliveries.status = 'delivered') as delivered,
                COUNT(*) FILTER (WHERE deliveries.status = 'cancelled') as cancelled,
                COALESCE(SUM(orders.delivery_fee) FILTER (WHERE deliveries.status = 'delivered'), 0) as earnings,
                AVG(EXTRACT(EPOCH FROM (deliveries.delivered_at - deliveries.assigned_at)) / 60)
                    FILTER (WHERE deliveries.status = 'delivered') as avg_minutes")
            ->orderByDesc('delivered')
            ->get()
            ->map(fn ($r) => [
                'driver_id' => $r->id,
                'name' => $r->name,
                'delivered' => (int) $r->delivered,
                'cancelled' => (int) $r->cancelled,
                'earnings' => round((float) $r->earnings, 2),
                'avg_delivery_minutes' => $r->avg_minutes ? round((float) $r->avg_minutes, 1) : null,
            ])->all();
    }

    private function orders(?array $storeIds): Builder
    {
        return Order::query()->when($storeIds !== null, fn ($q) => $q->whereIn('store_id', $storeIds));
    }
}
