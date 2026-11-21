import { Link } from 'react-router-dom'
import { Bike, ClipboardList, DollarSign, FileCheck2, GraduationCap, Store, Truck, Users } from 'lucide-react'
import { useApi } from '../../hooks/useApi'
import { Card, ErrorState, PageHeader, PageLoader, StatCard } from '../../components/ui'
import { DonutChart, HBarChart, RevenueChart } from '../../components/charts'
import { money, number, timeAgo } from '../../utils/format'

export default function AdminDashboard() {
  const { data, loading, error, reload } = useApi('/admin/dashboard', {}, { pollMs: 30000 })
  if (error) return <ErrorState message={error} onRetry={reload} />
  if (loading || !data) return <PageLoader />
  const t = data.totals

  return (
    <>
      <PageHeader title="Platform overview" subtitle="RUPP Eat across the whole campus." />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Total users" value={number(t.users)} hint={`${t.customers} customers · ${t.store_owners} store owners`} icon={Users} />
        <StatCard label="Students & staff" value={number(t.students + t.lecturers + t.staff)} hint={`${t.students} students · ${t.lecturers} lecturers · ${t.staff} staff`} icon={GraduationCap} tone="violet" />
        <StatCard label="Stores" value={t.stores} hint={`${t.active_stores} active`} icon={Store} tone="accent" />
        <StatCard label="Drivers" value={t.drivers} hint={`${data.online_drivers} online now`} icon={Bike} tone="green" />
        <StatCard label="Total orders" value={number(t.orders)} hint={`${data.today.total_orders} today`} icon={ClipboardList} />
        <StatCard label="Total revenue" value={money(t.revenue)} hint={`${money(data.today.revenue)} today`} icon={DollarSign} tone="green" />
        <StatCard label="Active deliveries" value={data.active_deliveries} hint={`${data.active_orders} active orders`} icon={Truck} tone="accent" />
        <StatCard label="Pending reviews" value={data.pending_store_applications + data.pending_driver_verifications} hint={`${data.pending_store_applications} stores · ${data.pending_driver_verifications} drivers`} icon={FileCheck2} tone="red" />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-3">
        <Card title="Revenue — last 14 days" className="lg:col-span-2"><RevenueChart data={data.revenue_14_days} /></Card>
        <Card title="Orders by status (14 days)"><DonutChart data={data.order_status} /></Card>
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <Card title="Top stores (14 days)" actions={<Link to="/admin/reports" className="text-sm font-semibold text-accent-600">Full reports</Link>}>
          {data.top_stores.length ? <HBarChart data={data.top_stores} dataKey="revenue" currency /> : <p className="text-sm text-muted">No sales yet.</p>}
        </Card>
        <Card title="System activity" actions={<Link to="/admin/activity" className="text-sm font-semibold text-accent-600">All logs</Link>}>
          <ul className="divide-y divide-line">
            {data.recent_activity.map((a) => (
              <li key={a.id} className="flex items-start gap-3 py-2.5 text-sm">
                <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-brand-600" />
                <div className="min-w-0 flex-1">
                  <p className="truncate">{a.description}</p>
                  <p className="text-xs text-muted">{a.user || 'System'} · {a.action}</p>
                </div>
                <span className="whitespace-nowrap text-xs text-muted">{timeAgo(a.created_at)}</span>
              </li>
            ))}
          </ul>
        </Card>
      </div>
    </>
  )
}
