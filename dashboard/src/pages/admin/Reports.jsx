import { useState } from 'react'
import { CheckCircle2, DollarSign, Download, Receipt, Truck } from 'lucide-react'
import { useApi } from '../../hooks/useApi'
import { download } from '../../api/client'
import { Card, DataTable, EmptyState, ErrorState, PageHeader, PageLoader, StatCard, useToast } from '../../components/ui'
import { DonutChart, HBarChart, RevenueChart } from '../../components/charts'
import ReportFilters from '../../components/ReportFilters'
import { money } from '../../utils/format'

export default function Reports() {
  const [filters, setFilters] = useState({ period: 'daily', from: '', to: '' })
  const { data, loading, error, reload } = useApi('/admin/reports', filters)
  const toast = useToast()

  const exportCsv = async (type) => {
    try {
      await download('/admin/reports/export', { type, from: data?.range.from, to: data?.range.to }, `rupp-eat-${type}-${data?.range.from}-${data?.range.to}.csv`)
    } catch (e) { toast(e.message || 'Export failed', 'error') }
  }

  return (
    <>
      <PageHeader title="Reports & analytics" subtitle="Platform-wide sales, stores, products and driver performance." />
      <ReportFilters value={filters} onChange={setFilters}>
        <div className="flex flex-wrap gap-2">
          {['orders', 'stores', 'products', 'drivers'].map((t) => (
            <button key={t} className="btn-outline btn-sm capitalize" onClick={() => exportCsv(t)} disabled={!data}><Download className="h-3.5 w-3.5" />{t} CSV</button>
          ))}
        </div>
      </ReportFilters>

      {error ? <ErrorState message={error} onRetry={reload} /> : loading || !data ? <PageLoader /> : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <StatCard label="Total sales" value={money(data.summary.revenue)} hint={`Food ${money(data.summary.food_sales)}`} icon={DollarSign} tone="green" />
            <StatCard label="Delivery fees" value={money(data.summary.delivery_fees)} icon={Truck} tone="accent" />
            <StatCard label="Completed orders" value={data.summary.completed_orders} hint={`${data.summary.total_orders} placed · ${data.summary.cancelled_orders} cancelled`} icon={CheckCircle2} />
            <StatCard label="Average order" value={money(data.summary.average_order_value)} icon={Receipt} tone="violet" />
          </div>

          <Card title={`Order & revenue trend (${data.range.from} → ${data.range.to})`} className="mt-6"><RevenueChart data={data.revenue} /></Card>

          <div className="mt-6 grid gap-6 lg:grid-cols-2">
            <Card title="Revenue by store (most popular stores)">
              {data.revenue_by_store.length ? <HBarChart data={data.revenue_by_store} dataKey="revenue" currency /> : <EmptyState title="No sales" />}
            </Card>
            <Card title="Most popular products">
              {data.best_sellers.length ? <HBarChart data={data.best_sellers.slice(0, 8)} dataKey="quantity" /> : <EmptyState title="No sales" />}
            </Card>
            <Card title="Order status"><DonutChart data={data.status_breakdown} /></Card>
            <Card title="Delivery vs pickup"><DonutChart data={data.fulfillment_split} labelFn={(k) => (k === 'delivery' ? 'Classroom delivery' : 'Self-pickup')} /></Card>
          </div>

          <Card title="Driver performance" className="mt-6" bodyClass="">
            <DataTable
              rowKey="driver_id"
              rows={data.driver_performance}
              empty={<EmptyState title="No deliveries in this period" />}
              columns={[
                { key: 'name', label: 'Driver', render: (d) => <span className="font-semibold">{d.name}</span> },
                { key: 'delivered', label: 'Delivered' },
                { key: 'cancelled', label: 'Cancelled' },
                { key: 'earnings', label: 'Delivery fees', render: (d) => money(d.earnings) },
                { key: 'avg', label: 'Avg time (assigned → delivered)', render: (d) => (d.avg_delivery_minutes ? `${d.avg_delivery_minutes} min` : '—') },
              ]}
            />
          </Card>
        </>
      )}
    </>
  )
}
