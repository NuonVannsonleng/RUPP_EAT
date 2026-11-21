import { useState } from 'react'
import { BadgeCheck, History, Plus, ShieldX } from 'lucide-react'
import { useApi } from '../../hooks/useApi'
import { patch } from '../../api/client'
import { Badge, Card, DataTable, EmptyState, Modal, PageHeader, PageLoader, Pagination, StatusBadge, Tabs, Toggle, useToast } from '../../components/ui'
import { dateTime, firstError, money } from '../../utils/format'
import { UserForm } from './Users'

export default function Drivers() {
  const [verification, setVerification] = useState('')
  const [page, setPage] = useState(1)
  const { data, meta, loading, reload } = useApi('/admin/users', { role: 'driver', verification, page })
  const { data: perf } = useApi('/admin/reports', { period: 'monthly' })
  const [creating, setCreating] = useState(false)
  const [historyFor, setHistoryFor] = useState(null)
  const toast = useToast()

  const perfById = Object.fromEntries((perf?.driver_performance || []).map((p) => [p.driver_id, p]))

  const verify = async (u, status) => {
    try {
      await patch(`/admin/drivers/${u.id}/verification`, { verification_status: status })
      toast(status === 'verified' ? `${u.name} verified` : `${u.name} rejected`)
      reload(true)
    } catch (e) { toast(firstError(e), 'error') }
  }

  const setActive = async (u, isActive) => {
    try {
      await patch(`/admin/drivers/${u.id}/active`, { is_active: isActive })
      toast(isActive ? 'Driver activated' : 'Driver deactivated')
      reload(true)
    } catch (e) { toast(firstError(e), 'error') }
  }

  return (
    <>
      <PageHeader title="Drivers" subtitle="Verify, activate and monitor campus delivery drivers." actions={<button className="btn-accent" onClick={() => setCreating(true)}><Plus className="h-4 w-4" />Register driver</button>} />
      <div className="mb-4">
        <Tabs value={verification} onChange={(v) => { setVerification(v); setPage(1) }} tabs={[{ value: '', label: 'All' }, { value: 'pending', label: 'Awaiting verification' }, { value: 'verified', label: 'Verified' }, { value: 'rejected', label: 'Rejected' }]} />
      </div>
      <div className="card overflow-hidden">
        <DataTable
          loading={loading}
          rows={data}
          empty={<EmptyState title="No drivers here" />}
          columns={[
            { key: 'name', label: 'Driver', render: (u) => <div><p className="font-semibold">{u.name}</p><p className="text-xs text-muted">{u.phone} · {u.email}</p></div> },
            { key: 'vehicle', label: 'Vehicle', render: (u) => <span className="capitalize">{u.driver_profile?.vehicle_type} {u.driver_profile?.plate_number && <span className="text-muted">· {u.driver_profile.plate_number}</span>}</span> },
            { key: 'verification', label: 'Verification', render: (u) => <StatusBadge status={u.driver_profile?.verification_status === 'pending' ? 'pending' : u.driver_profile?.verification_status === 'verified' ? 'verified' : 'rejected'} label={u.driver_profile?.verification_status} /> },
            { key: 'online', label: 'Now', render: (u) => u.driver_profile?.is_online ? <Badge tone="green">Online</Badge> : <Badge>Offline</Badge> },
            { key: 'perf', label: 'Delivered (period)', render: (u) => {
              const p = perfById[u.id]
              return p ? <span>{p.delivered} · {money(p.earnings)}{p.avg_delivery_minutes && <span className="text-muted"> · {p.avg_delivery_minutes} min avg</span>}</span> : <span className="text-muted">—</span>
            } },
            { key: 'active', label: 'Active', render: (u) => <Toggle checked={!!u.driver_profile?.is_active} onChange={(v) => setActive(u, v)} label="Active" /> },
            { key: 'a', label: '', className: 'text-right', render: (u) => (
              <div className="flex justify-end gap-1">
                {u.driver_profile?.verification_status !== 'verified' && <button className="btn-outline btn-sm text-emerald-700" onClick={() => verify(u, 'verified')}><BadgeCheck className="h-4 w-4" />Verify</button>}
                {u.driver_profile?.verification_status === 'pending' && <button className="btn-outline btn-sm text-red-600" onClick={() => verify(u, 'rejected')}><ShieldX className="h-4 w-4" />Reject</button>}
                <button className="btn-ghost p-2" title="Delivery history" onClick={() => setHistoryFor(u)}><History className="h-4 w-4" /></button>
              </div>
            ) },
          ]}
        />
        <Pagination meta={meta} onPage={setPage} />
      </div>
      {creating && <UserForm user={{}} defaultRole="driver" onClose={() => setCreating(false)} onSaved={() => { setCreating(false); reload(true) }} />}
      {historyFor && <DriverHistory driver={historyFor} onClose={() => setHistoryFor(null)} />}
    </>
  )
}

function DriverHistory({ driver, onClose }) {
  const [page, setPage] = useState(1)
  const { data, meta, loading } = useApi(`/admin/drivers/${driver.id}/deliveries`, { page })

  return (
    <Modal open onClose={onClose} size="lg" title={`${driver.name} — delivery history`}>
      {loading && !data ? <PageLoader /> : (
        <Card bodyClass="">
          <DataTable
            rows={data}
            empty={<EmptyState title="No deliveries yet" />}
            columns={[
              { key: 'order', label: 'Order', render: (d) => <span className="font-semibold">{d.order.order_number}</span> },
              { key: 'route', label: 'Route', render: (d) => <span className="text-xs">{d.store.name} → {d.order.delivery_location?.building} {d.order.delivery_location?.room}</span> },
              { key: 'status', label: 'Status', render: (d) => <StatusBadge status={d.status} /> },
              { key: 'fee', label: 'Fee', render: (d) => money(d.order.delivery_fee) },
              { key: 'time', label: 'Assigned → delivered', render: (d) => <span className="text-xs text-muted">{dateTime(d.assigned_at)}{d.delivered_at && ` → ${dateTime(d.delivered_at)}`}</span> },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </Card>
      )}
    </Modal>
  )
}
