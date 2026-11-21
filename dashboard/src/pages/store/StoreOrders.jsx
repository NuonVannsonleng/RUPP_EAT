import { useState } from 'react'
import { Bike, Check, ChefHat, MapPin, PackageCheck, Search, Store as StoreIcon, X } from 'lucide-react'
import { useAuth } from '../../context/AuthContext'
import { useApi, useDebounced } from '../../hooks/useApi'
import { patch, post } from '../../api/client'
import OrderDetailModal from '../../components/OrderDetailModal'
import { ConfirmDialog, DataTable, EmptyState, ErrorState, Field, PageHeader, Pagination, SearchInput, Spinner, StatusBadge, Tabs, useToast } from '../../components/ui'
import { firstError, money, timeAgo, dateTime } from '../../utils/format'

/**
 * Live order board: New → Preparing → Ready → Out for delivery.
 * Every action calls PATCH /api/orders/{id}/status (validated by the server's state machine).
 */
export default function StoreOrders() {
  const { storeId } = useAuth()
  const [view, setView] = useState('board')
  const board = useApi('/orders', { store_id: storeId, status: 'active', per_page: 100 }, { pollMs: 10000, enabled: !!storeId })
  const [openId, setOpenId] = useState(null)

  return (
    <>
      <PageHeader
        title="Orders"
        subtitle="New orders appear automatically. Accept quickly so students are not late for class!"
        actions={<Tabs value={view} onChange={setView} tabs={[{ value: 'board', label: 'Live board', count: board.data?.length }, { value: 'history', label: 'History' }]} />}
      />
      {view === 'board'
        ? <Board state={board} onOpen={setOpenId} />
        : <History storeId={storeId} onOpen={setOpenId} />}
      <OrderDetailModal
        orderId={openId}
        onClose={() => setOpenId(null)}
        actions={(order) => <OrderActions order={order} onDone={() => { setOpenId(null); board.reload(true) }} />}
      />
    </>
  )
}

const COLUMNS = [
  { key: 'new', title: 'New', statuses: ['pending'], icon: PackageCheck, tone: 'border-t-amber-400' },
  { key: 'kitchen', title: 'Accepted / preparing', statuses: ['accepted', 'preparing'], icon: ChefHat, tone: 'border-t-violet-500' },
  { key: 'ready', title: 'Ready', statuses: ['ready', 'driver_assigned'], icon: StoreIcon, tone: 'border-t-accent-500' },
  { key: 'out', title: 'Out for delivery', statuses: ['on_the_way'], icon: Bike, tone: 'border-t-brand-600' },
]

function Board({ state, onOpen }) {
  const { data, loading, error, reload } = state
  if (error) return <ErrorState message={error} onRetry={reload} />
  if (loading && !data) return <div className="flex justify-center py-20"><Spinner className="h-8 w-8" /></div>

  return (
    <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      {COLUMNS.map((col) => {
        const orders = (data || []).filter((o) => col.statuses.includes(o.status))
        return (
          <div key={col.key} className={`rounded-2xl border border-line border-t-4 bg-white/60 ${col.tone}`}>
            <div className="flex items-center gap-2 px-4 py-3">
              <col.icon className="h-4 w-4 text-muted" />
              <h3 className="flex-1 text-sm font-bold">{col.title}</h3>
              <span className="rounded-full bg-canvas px-2 text-xs font-bold">{orders.length}</span>
            </div>
            <div className="space-y-3 px-3 pb-3">
              {orders.length === 0 && <p className="py-6 text-center text-xs text-muted">No orders</p>}
              {orders.map((o) => <OrderCard key={o.id} order={o} onOpen={() => onOpen(o.id)} onDone={() => reload(true)} />)}
            </div>
          </div>
        )
      })}
    </div>
  )
}

function OrderCard({ order, onOpen, onDone }) {
  return (
    <div className="card cursor-pointer p-3.5 shadow-sm transition hover:shadow-md" onClick={onOpen}>
      <div className="flex items-start justify-between gap-2">
        <div>
          <p className="text-sm font-extrabold">{order.order_number}</p>
          <p className="text-xs text-muted">{order.customer?.name} · {timeAgo(order.created_at)}</p>
        </div>
        <span className="text-sm font-bold text-accent-600">{money(order.total)}</span>
      </div>
      <ul className="mt-2 space-y-0.5 text-xs">
        {order.items?.slice(0, 4).map((i) => <li key={i.id}><b>{i.quantity}×</b> {i.product_name}</li>)}
        {order.items?.length > 4 && <li className="text-muted">+{order.items.length - 4} more</li>}
      </ul>
      <div className="mt-2.5 flex flex-wrap items-center gap-1.5 text-xs">
        {order.fulfillment_method === 'delivery'
          ? <span className="inline-flex items-center gap-1 rounded-md bg-brand-50 px-2 py-0.5 font-semibold text-brand-700"><MapPin className="h-3 w-3" />{order.delivery_location?.building_code} {order.delivery_location?.room}</span>
          : <span className="rounded-md bg-accent-50 px-2 py-0.5 font-semibold text-accent-600">Pickup</span>}
        {order.delivery?.status === 'searching' && <StatusBadge status="searching" />}
        {order.driver && <span className="inline-flex items-center gap-1 text-muted"><Bike className="h-3 w-3" />{order.driver.name}</span>}
      </div>
      <div className="mt-3" onClick={(e) => e.stopPropagation()}>
        <OrderActions order={order} onDone={onDone} compact />
      </div>
    </div>
  )
}

/** Buttons for the next valid step of an order. */
export function OrderActions({ order, onDone, compact }) {
  const toast = useToast()
  const [busy, setBusy] = useState(false)
  const [reject, setReject] = useState(null) // 'rejected' | 'cancelled'
  const [reason, setReason] = useState('')
  const [pickup, setPickup] = useState(false)
  const [code, setCode] = useState('')

  const run = async (fn, msg) => {
    setBusy(true)
    try {
      await fn()
      toast(msg)
      onDone?.()
    } catch (e) {
      toast(firstError(e), 'error')
    } finally {
      setBusy(false)
    }
  }

  const setStatus = (status, extra = {}) => run(() => patch(`/orders/${order.id}/status`, { status, ...extra }), `Order ${order.order_number} updated`)
  const size = compact ? 'btn-sm' : ''
  const isDelivery = order.fulfillment_method === 'delivery'
  const deliveryPending = isDelivery && order.delivery?.status === 'pending'

  const buttons = []
  if (order.status === 'pending') {
    buttons.push(<button key="a" className={`btn-primary ${size}`} disabled={busy} onClick={() => setStatus('accepted')}><Check className="h-4 w-4" />Accept</button>)
    buttons.push(<button key="r" className={`btn-outline ${size} text-red-600`} disabled={busy} onClick={() => setReject('rejected')}><X className="h-4 w-4" />Reject</button>)
  }
  if (order.status === 'accepted') buttons.push(<button key="p" className={`btn-primary ${size}`} disabled={busy} onClick={() => setStatus('preparing')}><ChefHat className="h-4 w-4" />Start preparing</button>)
  if (order.status === 'preparing') buttons.push(<button key="rd" className={`btn-accent ${size}`} disabled={busy} onClick={() => setStatus('ready')}><PackageCheck className="h-4 w-4" />Mark ready</button>)
  if (deliveryPending && ['accepted', 'preparing'].includes(order.status)) {
    buttons.push(<button key="d" className={`btn-outline ${size}`} disabled={busy} onClick={() => run(() => post(`/orders/${order.id}/request-driver`), 'Looking for a driver')}><Bike className="h-4 w-4" />Request driver</button>)
  }
  if (order.status === 'ready' && !isDelivery) buttons.push(<button key="pu" className={`btn-accent ${size}`} disabled={busy} onClick={() => setPickup(true)}><Check className="h-4 w-4" />Confirm pickup</button>)
  if (['accepted', 'preparing', 'ready'].includes(order.status) && !compact) {
    buttons.push(<button key="c" className="btn-ghost text-red-600" disabled={busy} onClick={() => setReject('cancelled')}>Cancel order</button>)
  }
  if (order.status === 'ready' && isDelivery && compact) buttons.push(<span key="w" className="text-xs text-muted">{order.driver ? 'Driver on the way to collect' : 'Waiting for a driver…'}</span>)

  return (
    <>
      <div className="flex flex-wrap gap-2">{buttons}</div>
      <ConfirmDialog
        open={!!reject}
        title={reject === 'rejected' ? `Reject ${order.order_number}?` : `Cancel ${order.order_number}?`}
        message="The customer will be notified with your reason. Reserved stock is returned."
        confirmLabel={reject === 'rejected' ? 'Reject order' : 'Cancel order'}
        danger
        loading={busy}
        onClose={() => setReject(null)}
        onConfirm={() => { setStatus(reject, { reason: reason || 'Store unavailable' }); setReject(null) }}
      >
        <div className="mt-3 flex flex-wrap gap-2">
          {['Sold out', 'Store is too busy', 'Closing soon', 'Item unavailable'].map((r) => (
            <button key={r} type="button" onClick={() => setReason(r)} className={`rounded-full border px-3 py-1 text-xs font-semibold ${reason === r ? 'border-accent-500 bg-accent-50 text-accent-600' : 'border-line'}`}>{r}</button>
          ))}
        </div>
        <input className="input mt-3" placeholder="Or type a reason" value={reason} onChange={(e) => setReason(e.target.value)} />
      </ConfirmDialog>
      <ConfirmDialog
        open={pickup}
        title="Confirm pickup"
        message="Ask the customer for the 4-digit pickup code shown in their app."
        confirmLabel="Confirm pickup"
        loading={busy}
        onClose={() => setPickup(false)}
        onConfirm={() => { setStatus('picked_up', { pickup_code: code }); setPickup(false); setCode('') }}
      >
        <Field label="Pickup code"><input className="input mt-2 text-center text-2xl font-black tracking-[0.5em]" maxLength={4} value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))} autoFocus /></Field>
      </ConfirmDialog>
    </>
  )
}

function History({ storeId, onOpen }) {
  const [page, setPage] = useState(1)
  const [status, setStatus] = useState('')
  const [search, setSearch] = useState('')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const q = useDebounced(search)
  const { data, meta, loading, error, reload } = useApi('/orders', { store_id: storeId, page, status, search: q, date_from: from, date_to: to })

  return (
    <div className="card overflow-hidden">
      <div className="flex flex-col gap-3 border-b border-line p-4 lg:flex-row lg:items-center">
        <SearchInput value={search} onChange={(v) => { setSearch(v); setPage(1) }} placeholder="Order # or customer" />
        <select className="input lg:w-48" value={status} onChange={(e) => { setStatus(e.target.value); setPage(1) }}>
          <option value="">All statuses</option>
          <option value="completed">Completed</option>
          <option value="cancelled">Cancelled / rejected</option>
          <option value="active">Active</option>
        </select>
        <input type="date" className="input lg:w-44" value={from} onChange={(e) => setFrom(e.target.value)} />
        <input type="date" className="input lg:w-44" value={to} onChange={(e) => setTo(e.target.value)} />
      </div>
      {error ? <ErrorState message={error} onRetry={reload} /> : (
        <DataTable
          loading={loading}
          rows={data}
          onRowClick={(o) => onOpen(o.id)}
          empty={<EmptyState icon={Search} title="No orders match" />}
          columns={[
            { key: 'order_number', label: 'Order', render: (o) => <span className="font-semibold">{o.order_number}</span> },
            { key: 'created_at', label: 'Date', render: (o) => dateTime(o.created_at) },
            { key: 'customer', label: 'Customer', render: (o) => o.customer?.name },
            { key: 'type', label: 'Type', render: (o) => (o.fulfillment_method === 'delivery' ? `Delivery · ${o.delivery_location?.room || ''}` : 'Pickup') },
            { key: 'total', label: 'Total', render: (o) => money(o.total) },
            { key: 'status', label: 'Status', render: (o) => <StatusBadge status={o.status} label={o.status_label} /> },
          ]}
        />
      )}
      <Pagination meta={meta} onPage={setPage} />
    </div>
  )
}
