import { useState } from 'react'
import { LifeBuoy } from 'lucide-react'
import { useApi } from '../../hooks/useApi'
import { post } from '../../api/client'
import OrderDetailModal from '../../components/OrderDetailModal'
import { OrderActions } from '../store/StoreOrders'
import { ConfirmDialog, DataTable, EmptyState, PageHeader, Pagination, StatusBadge, Tabs, useToast } from '../../components/ui'
import { dateTime, firstError, money } from '../../utils/format'

/** Support tickets and order disputes from customers and drivers. */
export default function Support() {
  const [status, setStatus] = useState('open')
  const [page, setPage] = useState(1)
  const { data, meta, loading, reload } = useApi('/admin/support-tickets', { status, page })
  const [resolving, setResolving] = useState(null)
  const [resolution, setResolution] = useState('')
  const [orderId, setOrderId] = useState(null)
  const toast = useToast()

  const resolve = async () => {
    try {
      await post(`/admin/support-tickets/${resolving.id}/resolve`, { resolution })
      toast('Ticket resolved — the user was notified')
      setResolving(null)
      setResolution('')
      reload(true)
    } catch (e) { toast(firstError(e), 'error') }
  }

  return (
    <>
      <PageHeader title="Support & disputes" subtitle="Messages sent from the mobile app's Contact support screen." />
      <div className="mb-4"><Tabs value={status} onChange={(v) => { setStatus(v); setPage(1) }} tabs={[{ value: 'open', label: 'Open' }, { value: 'resolved', label: 'Resolved' }, { value: '', label: 'All' }]} /></div>
      <div className="card overflow-hidden">
        <DataTable loading={loading} rows={data} empty={<EmptyState icon={LifeBuoy} title="No tickets" />} columns={[
          { key: 'created_at', label: 'Received', render: (t) => <span className="whitespace-nowrap text-xs">{dateTime(t.created_at)}</span> },
          { key: 'user', label: 'From', render: (t) => <div className="text-sm"><p className="font-semibold">{t.user?.name}</p><p className="text-xs text-muted">{t.user?.phone}</p></div> },
          { key: 'subject', label: 'Message', render: (t) => <div className="max-w-md"><p className="font-semibold">{t.subject}</p><p className="text-sm text-muted">{t.message}</p>{t.resolution && <p className="mt-1 text-xs text-emerald-700">✔ {t.resolution}</p>}</div> },
          { key: 'order', label: 'Order', render: (t) => t.order ? <button className="text-sm font-semibold text-brand-600 hover:underline" onClick={() => setOrderId(t.order.id)}>{t.order.order_number}<span className="block text-xs font-normal text-muted">{t.order.status} · {money(t.order.total)}</span></button> : '—' },
          { key: 'status', label: 'Status', render: (t) => <StatusBadge status={t.status} /> },
          { key: 'a', label: '', render: (t) => t.status === 'open' && <button className="btn-primary btn-sm" onClick={() => setResolving(t)}>Resolve</button> },
        ]} />
        <Pagination meta={meta} onPage={setPage} />
      </div>
      <ConfirmDialog open={!!resolving} title={`Resolve: ${resolving?.subject}`} confirmLabel="Resolve & notify" onClose={() => setResolving(null)} onConfirm={resolve}>
        <textarea className="input mt-2" rows={4} placeholder="Resolution sent to the user (e.g. refunded in cash at the store)" value={resolution} onChange={(e) => setResolution(e.target.value)} />
      </ConfirmDialog>
      <OrderDetailModal orderId={orderId} onClose={() => setOrderId(null)} actions={(order) => <OrderActions order={order} onDone={() => setOrderId(null)} />} />
    </>
  )
}
