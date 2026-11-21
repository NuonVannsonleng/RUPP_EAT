import { Link } from 'react-router-dom'
import { CheckCircle2, ChefHat, Clock, DollarSign, PackageCheck, Truck } from 'lucide-react'
import { useAuth } from '../../context/AuthContext'
import { useApi } from '../../hooks/useApi'
import { Card, DataTable, EmptyState, ErrorState, PageHeader, PageLoader, StatCard, StatusBadge } from '../../components/ui'
import { HBarChart, RevenueChart } from '../../components/charts'
import { money, timeAgo } from '../../utils/format'

export default function StoreDashboard() {
  const { storeId, stores } = useAuth()
  const { data, loading, error, reload } = useApi('/store/dashboard', { store_id: storeId }, { pollMs: 15000, enabled: !!storeId })

  if (!stores.length) return <EmptyState title="No store linked to your account" message="Ask the RUPP Eat administrator to assign your store." />
  if (error) return <ErrorState message={error} onRetry={reload} />
  if (loading || !data) return <PageLoader />

  return (
    <>
      <PageHeader title="Today at your store" subtitle="Live overview — refreshes automatically every 15 seconds." actions={<Link to="/store/orders" className="btn-accent">Open order board</Link>} />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Today's orders" value={data.today.orders} hint={`${data.today.completed} completed · ${data.today.cancelled} cancelled`} icon={PackageCheck} />
        <StatCard label="Pending confirmation" value={data.pending} hint="Accept or reject quickly" icon={Clock} tone="accent" />
        <StatCard label="Being prepared" value={data.in_progress} hint={`${data.ready} ready · ${data.out_for_delivery} out for delivery`} icon={ChefHat} tone="violet" />
        <StatCard label="Today's sales" value={money(data.today.sales)} hint="Completed orders only" icon={DollarSign} tone="green" />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-3">
        <Card title="Sales — last 7 days" className="lg:col-span-2"><RevenueChart data={data.sales_last_7_days} height={260} /></Card>
        <Card title="Popular products (30 days)">
          {data.popular_products.length ? <HBarChart data={data.popular_products} dataKey="quantity" /> : <EmptyState title="No sales yet" />}
        </Card>
      </div>

      <Card title="Recent orders" className="mt-6" bodyClass="" actions={<Link to="/store/orders" className="text-sm font-semibold text-accent-600">View all</Link>}>
        <DataTable
          rows={data.recent_orders}
          columns={[
            { key: 'order_number', label: 'Order', render: (o) => <span className="font-semibold">{o.order_number}</span> },
            { key: 'customer', label: 'Customer', render: (o) => o.customer?.name },
            { key: 'fulfillment_method', label: 'Type', render: (o) => (o.fulfillment_method === 'delivery' ? <span className="inline-flex items-center gap-1"><Truck className="h-3.5 w-3.5" /> {o.delivery_location?.room}</span> : <span className="inline-flex items-center gap-1"><CheckCircle2 className="h-3.5 w-3.5" /> Pickup</span>) },
            { key: 'total', label: 'Total', render: (o) => money(o.total) },
            { key: 'status', label: 'Status', render: (o) => <StatusBadge status={o.status} label={o.status_label} /> },
            { key: 'created_at', label: 'Placed', render: (o) => <span className="text-muted">{timeAgo(o.created_at)}</span> },
          ]}
        />
      </Card>
    </>
  )
}
