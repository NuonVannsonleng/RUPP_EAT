import { useState } from 'react'
import { CheckCircle2, DollarSign, Receipt, XCircle } from 'lucide-react'
import { useAuth } from '../../context/AuthContext'
import { useApi } from '../../hooks/useApi'
import { Card, DataTable, EmptyState, ErrorState, PageHeader, PageLoader, StatCard } from '../../components/ui'
import { DonutChart, RevenueChart } from '../../components/charts'
import ReportFilters from '../../components/ReportFilters'
import { money } from '../../utils/format'

export default function StoreReports() {
  const { storeId } = useAuth()
  const [filters, setFilters] = useState({ period: 'daily', from: '', to: '' })
  const { data, loading, error, reload } = useApi('/store/reports', { store_id: storeId, ...filters }, { enabled: !!storeId })

  return (
    <>
      <PageHeader title="Sales & reports" subtitle="Revenue counts completed (delivered or picked-up) orders." />
      <ReportFilters value={filters} onChange={setFilters} />
      {error ? <ErrorState message={error} onRetry={reload} /> : loading || !data ? <PageLoader /> : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <StatCard label="Revenue" value={money(data.summary.revenue)} hint={`Food ${money(data.summary.food_sales)} · delivery ${money(data.summary.delivery_fees)}`} icon={DollarSign} tone="green" />
            <StatCard label="Completed orders" value={data.summary.completed_orders} hint={`of ${data.summary.total_orders} placed`} icon={CheckCircle2} />
            <StatCard label="Average order" value={money(data.summary.average_order_value)} icon={Receipt} tone="accent" />
            <StatCard label="Cancelled / rejected" value={data.summary.cancelled_orders} icon={XCircle} tone="red" />
          </div>
          <Card title={`Revenue (${data.range.from} → ${data.range.to})`} className="mt-6"><RevenueChart data={data.revenue} /></Card>
          <div className="mt-6 grid gap-6 lg:grid-cols-2">
            <Card title="Order status"><DonutChart data={data.status_breakdown} /></Card>
            <Card title="Delivery vs pickup"><DonutChart data={data.fulfillment_split} labelFn={(k) => (k === 'delivery' ? 'Classroom delivery' : 'Self-pickup')} /></Card>
          </div>
          <Card title="Best-selling products" className="mt-6" bodyClass="">
            <DataTable
              rowKey="name"
              rows={data.best_sellers}
              empty={<EmptyState title="No sales in this period" />}
              columns={[
                { key: 'rank', label: '#', render: (r) => data.best_sellers.indexOf(r) + 1 },
                { key: 'name', label: 'Product', render: (r) => <span className="font-semibold">{r.name}</span> },
                { key: 'quantity', label: 'Sold' },
                { key: 'revenue', label: 'Revenue', render: (r) => money(r.revenue) },
              ]}
            />
          </Card>
        </>
      )}
    </>
  )
}
