import { useState } from 'react'
import { Search } from 'lucide-react'
import { useApi, useDebounced } from '../../hooks/useApi'
import OrderDetailModal from '../../components/OrderDetailModal'
import { OrderActions } from '../store/StoreOrders'
import { DataTable, EmptyState, ErrorState, PageHeader, Pagination, SearchInput, StatusBadge, Tabs } from '../../components/ui'
import { dateTime, money } from '../../utils/format'

/** All orders on the platform with filters by store, customer, driver, date and status. */
export default function AdminOrders() {
  const [page, setPage] = useState(1)
  const [tab, setTab] = useState('')
  const [filters, setFilters] = useState({ search: '', store_id: '', driver_id: '', fulfillment_method: '', date_from: '', date_to: '' })
  const q = useDebounced(filters.search)
  const { data: stores } = useApi('/admin/stores', { per_page: 100 })
  const { data: drivers } = useApi('/admin/users', { role: 'driver', per_page: 100 })
  const { data, meta, loading, error, reload } = useApi('/admin/orders', { ...filters, search: q, status: tab, page }, { pollMs: tab === 'active' ? 15000 : undefined })
  const [openId, setOpenId] = useState(null)
  const set = (k) => (e) => { setFilters({ ...filters, [k]: e.target.value }); setPage(1) }

  return (
    <>
      <PageHeader title="Orders" subtitle="Monitor ongoing deliveries and resolve disputes. Admins can cancel any active order." />
      <div className="mb-4">
        <Tabs value={tab} onChange={(v) => { setTab(v); setPage(1) }} tabs={[{ value: '', label: 'All' }, { value: 'active', label: 'Active / ongoing' }, { value: 'completed', label: 'Completed' }, { value: 'cancelled', label: 'Cancelled' }]} />
      </div>
      <div className="card overflow-hidden">
        <div className="grid gap-3 border-b border-line p-4 md:grid-cols-3 xl:grid-cols-6">
          <div className="xl:col-span-2"><SearchInput value={filters.search} onChange={(v) => { setFilters({ ...filters, search: v }); setPage(1) }} placeholder="Order #, customer, student ID" /></div>
          <select className="input" value={filters.store_id} onChange={set('store_id')}>
            <option value="">All stores</option>{stores?.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
          <select className="input" value={filters.driver_id} onChange={set('driver_id')}>
            <option value="">All drivers</option>{drivers?.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}
          </select>
          <input type="date" className="input" value={filters.date_from} onChange={set('date_from')} aria-label="From" />
          <input type="date" className="input" value={filters.date_to} onChange={set('date_to')} aria-label="To" />
        </div>
        {error ? <ErrorState message={error} onRetry={reload} /> : (
          <DataTable
            loading={loading}
            rows={data}
            onRowClick={(o) => setOpenId(o.id)}
            empty={<EmptyState icon={Search} title="No orders match these filters" />}
            columns={[
              { key: 'order_number', label: 'Order', render: (o) => <span className="font-semibold">{o.order_number}</span> },
              { key: 'created_at', label: 'Placed', render: (o) => <span className="text-xs">{dateTime(o.created_at)}</span> },
              { key: 'store', label: 'Store', render: (o) => o.store?.name },
              { key: 'customer', label: 'Customer', render: (o) => o.customer?.name },
              { key: 'type', label: 'Fulfillment', render: (o) => (o.fulfillment_method === 'delivery' ? <span className="text-xs">Delivery → {o.delivery_location?.building_code} {o.delivery_location?.room}</span> : <span className="text-xs">Pickup</span>) },
              { key: 'driver', label: 'Driver', render: (o) => o.driver?.name || <span className="text-muted">—</span> },
              { key: 'total', label: 'Total', render: (o) => money(o.total) },
              { key: 'status', label: 'Status', render: (o) => <StatusBadge status={o.status} label={o.status_label} /> },
            ]}
          />
        )}
        <Pagination meta={meta} onPage={setPage} />
      </div>
      <OrderDetailModal orderId={openId} onClose={() => setOpenId(null)} actions={(order) => <OrderActions order={order} onDone={() => { setOpenId(null); reload(true) }} />} />
    </>
  )
}
