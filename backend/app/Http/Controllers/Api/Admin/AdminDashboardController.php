<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\DeliveryStatus;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Store;
use App\Models\StoreApplication;
use App\Models\SupportTicket;
use App\Models\User;
use App\Services\ReportService;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AdminDashboardController extends Controller
{
    public function __construct(private ReportService $reports) {}

    /** GET /api/admin/dashboard */
    public function dashboard(): JsonResponse
    {
        $byRole = User::join('roles', 'roles.id', '=', 'users.role_id')
            ->selectRaw('roles.name, COUNT(*) as c')->groupBy('roles.name')->pluck('c', 'roles.name');
        $byType = User::whereNotNull('user_type')->selectRaw('user_type, COUNT(*) as c')->groupBy('user_type')->pluck('c', 'user_type');

        $from = CarbonImmutable::today()->subDays(13);
        $to = CarbonImmutable::now()->endOfDay();
        $allTime = $this->reports->summary(null, CarbonImmutable::create(2000), $to);

        return $this->ok([
            'totals' => [
                'users' => (int) $byRole->sum(),
                'customers' => (int) ($byRole['customer'] ?? 0),
                'students' => (int) ($byType['student'] ?? 0),
                'lecturers' => (int) ($byType['lecturer'] ?? 0),
                'staff' => (int) ($byType['staff'] ?? 0),
                'store_owners' => (int) ($byRole['store_owner'] ?? 0),
                'drivers' => (int) ($byRole['driver'] ?? 0),
                'stores' => Store::count(),
                'active_stores' => Store::where('status', 'active')->count(),
                'orders' => $allTime['total_orders'],
                'revenue' => $allTime['revenue'],
            ],
            'today' => $this->reports->summary(null, CarbonImmutable::today(), $to),
            'pending_store_applications' => StoreApplication::where('status', 'pending')->count(),
            'pending_driver_verifications' => DriverProfile::where('verification_status', 'pending')->count(),
            'online_drivers' => DriverProfile::where('is_online', true)->count(),
            'active_deliveries' => Delivery::whereIn('status', [...DeliveryStatus::active(), DeliveryStatus::Searching])->count(),
            'active_orders' => Order::whereIn('status', ['pending', 'accepted', 'preparing', 'ready', 'driver_assigned', 'on_the_way'])->count(),
            'open_support_tickets' => SupportTicket::where('status', 'open')->count(),
            'revenue_14_days' => $this->reports->revenueSeries(null, $from, $to, 'daily'),
            'order_status' => $this->reports->statusBreakdown(null, $from, $to),
            'top_stores' => array_slice($this->reports->revenueByStore($from, $to), 0, 5),
            'recent_activity' => ActivityLog::with('user:id,name')->latest('created_at')->limit(10)->get()->map(fn ($l) => [
                'id' => $l->id,
                'action' => $l->action,
                'description' => $l->description,
                'user' => $l->user?->name,
                'created_at' => $l->created_at,
            ]),
        ]);
    }

    /** GET /api/admin/reports?period=daily|weekly|monthly&from=&to= */
    public function reports(Request $request): JsonResponse
    {
        [$period, $from, $to] = $this->parseRange($request);

        return $this->ok([
            'range' => ['from' => $from->toDateString(), 'to' => $to->toDateString(), 'period' => $period],
            'summary' => $this->reports->summary(null, $from, $to),
            'revenue' => $this->reports->revenueSeries(null, $from, $to, $period),
            'revenue_by_store' => $this->reports->revenueByStore($from, $to),
            'best_sellers' => $this->reports->bestSellers(null, $from, $to),
            'driver_performance' => $this->reports->driverPerformance($from, $to),
            'status_breakdown' => $this->reports->statusBreakdown(null, $from, $to),
            'fulfillment_split' => $this->reports->fulfillmentSplit(null, $from, $to),
        ]);
    }

    /** GET /api/admin/reports/export?type=orders|stores|products|drivers&from=&to= — CSV download. */
    public function export(Request $request): StreamedResponse
    {
        $request->validate(['type' => ['required', 'in:orders,stores,products,drivers']]);
        [, $from, $to] = $this->parseRange($request);
        $type = $request->type;

        [$header, $rows] = match ($type) {
            'stores' => [['Store', 'Completed orders', 'Revenue (USD)'],
                collect($this->reports->revenueByStore($from, $to))->map(fn ($r) => [$r['name'], $r['orders'], $r['revenue']])],
            'products' => [['Product', 'Store', 'Quantity sold', 'Revenue (USD)'],
                collect($this->reports->bestSellers(null, $from, $to, 1000))->map(fn ($r) => [$r['name'], $r['store_name'], $r['quantity'], $r['revenue']])],
            'drivers' => [['Driver', 'Delivered', 'Cancelled', 'Delivery fees (USD)', 'Avg minutes'],
                collect($this->reports->driverPerformance($from, $to))->map(fn ($r) => [$r['name'], $r['delivered'], $r['cancelled'], $r['earnings'], $r['avg_delivery_minutes']])],
            default => [['Order #', 'Date', 'Store', 'Customer', 'Method', 'Payment', 'Status', 'Subtotal', 'Delivery fee', 'Total'],
                Order::with(['store:id,name', 'customer:id,name'])->whereBetween('created_at', [$from, $to])->latest()->cursor()
                    ->map(fn ($o) => [$o->order_number, $o->created_at->format('Y-m-d H:i'), $o->store->name, $o->customer->name,
                        $o->fulfillment_method->value, $o->payment_method->value, $o->status->value, $o->subtotal, $o->delivery_fee, $o->total])],
        };

        $filename = "rupp-eat-$type-{$from->toDateString()}-to-{$to->toDateString()}.csv";

        return response()->streamDownload(function () use ($header, $rows) {
            $out = fopen('php://output', 'w');
            fwrite($out, "\xEF\xBB\xBF"); // UTF-8 BOM for Excel
            fputcsv($out, $header);
            foreach ($rows as $row) {
                fputcsv($out, $row);
            }
            fclose($out);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    private function parseRange(Request $request): array
    {
        $request->validate([
            'period' => ['nullable', 'in:daily,weekly,monthly'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
        ]);
        $period = $request->input('period', 'daily');

        return [$period, ...$this->reports->range($period, $request->from, $request->to)];
    }
}
