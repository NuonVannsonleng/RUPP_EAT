import { useState } from 'react'
import { Pencil, Plus } from 'lucide-react'
import { useApi, useDebounced } from '../../hooks/useApi'
import { patch, postForm } from '../../api/client'
import { Badge, ConfirmDialog, DataTable, ErrorState, Field, Img, Modal, PageHeader, Pagination, SearchInput, Spinner, StatusBadge, Toggle, useToast } from '../../components/ui'
import { firstError, money } from '../../utils/format'

export default function Stores() {
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('')
  const q = useDebounced(search)
  const { data, meta, loading, error, reload } = useApi('/admin/stores', { page, search: q, status })
  const [editing, setEditing] = useState(null)
  const [suspending, setSuspending] = useState(null)
  const toast = useToast()

  const changeStatus = async () => {
    const next = suspending.status === 'active' ? 'suspended' : 'active'
    try {
      await patch(`/admin/stores/${suspending.id}/status`, { status: next })
      toast(next === 'active' ? 'Store activated' : 'Store suspended')
      setSuspending(null)
      reload(true)
    } catch (e) { toast(firstError(e), 'error') }
  }

  const toggleFeatured = async (s) => {
    try {
      await postForm(`/stores/${s.id}`, { is_featured: !s.is_featured }, 'PUT')
      reload(true)
    } catch (e) { toast(firstError(e), 'error') }
  }

  return (
    <>
      <PageHeader title="Stores" subtitle="Every campus store, with activity and revenue." actions={<button className="btn-accent" onClick={() => setEditing({})}><Plus className="h-4 w-4" />Register store</button>} />
      <div className="card overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-line p-4 md:flex-row">
          <SearchInput value={search} onChange={(v) => { setSearch(v); setPage(1) }} placeholder="Store name" />
          <select className="input md:w-44" value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">Any status</option><option value="active">Active</option><option value="suspended">Suspended</option>
          </select>
        </div>
        {error ? <ErrorState message={error} onRetry={reload} /> : (
          <DataTable
            loading={loading}
            rows={data}
            columns={[
              { key: 'name', label: 'Store', render: (s) => (
                <div className="flex items-center gap-3">
                  <Img src={s.logo_url} className="h-10 w-10 rounded-xl" />
                  <div><p className="font-semibold">{s.name}</p><p className="text-xs text-muted">{s.building?.name} · {s.opening_time}–{s.closing_time}</p></div>
                </div>
              ) },
              { key: 'owner', label: 'Owner', render: (s) => <div className="text-sm"><p>{s.owner?.name}</p><p className="text-xs text-muted">{s.owner?.email}</p></div> },
              { key: 'activity', label: 'Activity', render: (s) => <span className="text-sm">{s.orders_today} today · {s.orders_count} total</span> },
              { key: 'revenue', label: 'Revenue', render: (s) => money(s.revenue) },
              { key: 'rating', label: 'Rating', render: (s) => `★ ${s.rating_avg || '—'} (${s.rating_count})` },
              { key: 'open', label: 'Now', render: (s) => s.is_open_now ? <Badge tone="green">Open</Badge> : <Badge>Closed</Badge> },
              { key: 'featured', label: 'Featured', render: (s) => <Toggle checked={s.is_featured} onChange={() => toggleFeatured(s)} label="Featured" /> },
              { key: 'status', label: 'Status', render: (s) => <button onClick={() => setSuspending(s)} title="Change status"><StatusBadge status={s.status} /></button> },
              { key: 'a', label: '', render: (s) => <button className="btn-ghost p-2" onClick={() => setEditing(s)} title="Edit"><Pencil className="h-4 w-4" /></button> },
            ]}
          />
        )}
        <Pagination meta={meta} onPage={setPage} />
      </div>
      {editing && <StoreForm store={editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); reload(true) }} />}
      <ConfirmDialog
        open={!!suspending}
        title={suspending?.status === 'active' ? `Suspend ${suspending?.name}?` : `Activate ${suspending?.name}?`}
        message={suspending?.status === 'active' ? 'The store disappears from the app and cannot receive orders.' : 'The store becomes visible again.'}
        confirmLabel={suspending?.status === 'active' ? 'Suspend' : 'Activate'}
        danger={suspending?.status === 'active'}
        onClose={() => setSuspending(null)}
        onConfirm={changeStatus}
      />
    </>
  )
}

function StoreForm({ store, onClose, onSaved }) {
  const isNew = !store.id
  const toast = useToast()
  const { data: owners } = useApi('/admin/users', { role: 'store_owner', per_page: 100 })
  const { data: campus } = useApi('/campus/locations')
  const buildings = (campus || []).flatMap((f) => f.buildings)
  const [form, setForm] = useState({
    owner_id: store.owner?.id || '', name: store.name || '', description: store.description || '', building_id: store.building?.id || '',
    location_note: store.location_note || '', phone: store.phone || '', opening_time: store.opening_time || '07:00', closing_time: store.closing_time || '17:00',
  })
  const [errors, setErrors] = useState({})
  const [saving, setSaving] = useState(false)
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })
  const err = (k) => errors[k]?.[0]

  const save = async () => {
    setSaving(true)
    try {
      const body = { ...form, building_id: form.building_id || null }
      if (isNew) await postForm('/stores', body)
      else await postForm(`/stores/${store.id}`, body, 'PUT')
      toast(isNew ? 'Store registered' : 'Store updated')
      onSaved()
    } catch (e) {
      setErrors(e.errors || {})
      toast(firstError(e), 'error')
    } finally { setSaving(false) }
  }

  return (
    <Modal open onClose={onClose} title={isNew ? 'Register store' : `Edit ${store.name}`}
      footer={<><button className="btn-outline" onClick={onClose}>Cancel</button><button className="btn-primary" disabled={saving} onClick={save}>{saving && <Spinner className="h-4 w-4 text-white" />}Save</button></>}>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Owner account" error={err('owner_id')} hint="Create a Store owner user first if needed">
          <select className="input" value={form.owner_id} onChange={set('owner_id')}>
            <option value="">Select owner</option>
            {owners?.map((o) => <option key={o.id} value={o.id}>{o.name} ({o.email})</option>)}
          </select>
        </Field>
        <Field label="Store name" error={err('name')}><input className="input" value={form.name} onChange={set('name')} /></Field>
        <div className="sm:col-span-2"><Field label="Description" error={err('description')}><textarea className="input" rows={2} value={form.description} onChange={set('description')} /></Field></div>
        <Field label="Building" error={err('building_id')}>
          <select className="input" value={form.building_id} onChange={set('building_id')}>
            <option value="">Select building</option>
            {buildings.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
          </select>
        </Field>
        <Field label="Location note" error={err('location_note')}><input className="input" value={form.location_note} onChange={set('location_note')} /></Field>
        <Field label="Phone" error={err('phone')}><input className="input" value={form.phone} onChange={set('phone')} /></Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Opens" error={err('opening_time')}><input type="time" className="input" value={form.opening_time} onChange={set('opening_time')} /></Field>
          <Field label="Closes" error={err('closing_time')}><input type="time" className="input" value={form.closing_time} onChange={set('closing_time')} /></Field>
        </div>
      </div>
    </Modal>
  )
}
