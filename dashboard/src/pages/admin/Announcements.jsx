import { useState } from 'react'
import { Megaphone, Pencil, Plus, Trash2 } from 'lucide-react'
import { useApi } from '../../hooks/useApi'
import { del, postForm } from '../../api/client'
import { Badge, ConfirmDialog, EmptyState, Field, Img, Modal, PageHeader, PageLoader, Pagination, Spinner, Toggle, useToast } from '../../components/ui'
import { date, firstError } from '../../utils/format'

export default function Announcements() {
  const [page, setPage] = useState(1)
  const { data, meta, loading, reload } = useApi('/admin/announcements', { page })
  const [editing, setEditing] = useState(null)
  const [deleting, setDeleting] = useState(null)
  const toast = useToast()

  const remove = async () => {
    try { await del(`/admin/announcements/${deleting.id}`); toast('Deleted'); setDeleting(null); reload(true) } catch (e) { toast(firstError(e), 'error') }
  }

  return (
    <>
      <PageHeader title="Announcements & promotions" subtitle="Shown on the mobile home screen (customers) or driver app." actions={<button className="btn-accent" onClick={() => setEditing({})}><Plus className="h-4 w-4" />New announcement</button>} />
      {loading && !data ? <PageLoader /> : !data?.length ? <div className="card"><EmptyState icon={Megaphone} title="No announcements" /></div> : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {data.map((a) => (
            <div key={a.id} className="card overflow-hidden">
              <Img src={a.image_url} className="h-32 w-full" />
              <div className="p-4">
                <div className="mb-2 flex flex-wrap gap-1.5">
                  <Badge tone={a.type === 'promotion' ? 'orange' : 'blue'}>{a.type}</Badge>
                  <Badge>{a.audience}</Badge>
                  {!a.is_active && <Badge tone="red">Hidden</Badge>}
                  {a.store && <Badge tone="violet">{a.store.name}</Badge>}
                </div>
                <h3 className="font-bold">{a.title}</h3>
                <p className="mt-1 line-clamp-3 text-sm text-muted">{a.body}</p>
                <div className="mt-3 flex items-center justify-between text-xs text-muted">
                  <span>{date(a.created_at)}{a.ends_at && ` · until ${date(a.ends_at)}`}</span>
                  <span className="flex gap-1">
                    <button className="btn-ghost p-1.5" onClick={() => setEditing(a)}><Pencil className="h-4 w-4" /></button>
                    <button className="btn-ghost p-1.5 text-red-600" onClick={() => setDeleting(a)}><Trash2 className="h-4 w-4" /></button>
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
      <div className="mt-4"><Pagination meta={meta} onPage={setPage} /></div>
      {editing && <AnnouncementForm item={editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); reload(true) }} />}
      <ConfirmDialog open={!!deleting} title="Delete announcement?" confirmLabel="Delete" danger onClose={() => setDeleting(null)} onConfirm={remove} />
    </>
  )
}

function AnnouncementForm({ item, onClose, onSaved }) {
  const isNew = !item.id
  const toast = useToast()
  const { data: stores } = useApi('/admin/stores', { per_page: 100 })
  const [form, setForm] = useState({
    title: item.title || '', body: item.body || '', type: item.type || 'announcement', audience: item.audience || 'all',
    store_id: item.store_id || '', is_active: item.is_active ?? true, starts_at: item.starts_at?.slice(0, 10) || '', ends_at: item.ends_at?.slice(0, 10) || '',
  })
  const [image, setImage] = useState(null)
  const [errors, setErrors] = useState({})
  const [saving, setSaving] = useState(false)
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })

  const save = async () => {
    setSaving(true)
    try {
      const body = { ...form, store_id: form.store_id || null, starts_at: form.starts_at || null, ends_at: form.ends_at || null, image: image || undefined }
      await postForm(isNew ? '/admin/announcements' : `/admin/announcements/${item.id}`, body)
      toast('Saved'); onSaved()
    } catch (e) { setErrors(e.errors || {}); toast(firstError(e), 'error') } finally { setSaving(false) }
  }

  return (
    <Modal open onClose={onClose} title={isNew ? 'New announcement' : 'Edit announcement'}
      footer={<><button className="btn-outline" onClick={onClose}>Cancel</button><button className="btn-primary" disabled={saving} onClick={save}>{saving && <Spinner className="h-4 w-4 text-white" />}Publish</button></>}>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="sm:col-span-2"><Field label="Title" error={errors.title?.[0]}><input className="input" value={form.title} onChange={set('title')} /></Field></div>
        <div className="sm:col-span-2"><Field label="Message" error={errors.body?.[0]}><textarea className="input" rows={3} value={form.body} onChange={set('body')} /></Field></div>
        <Field label="Type"><select className="input" value={form.type} onChange={set('type')}><option value="announcement">Announcement</option><option value="promotion">Promotion</option></select></Field>
        <Field label="Audience"><select className="input" value={form.audience} onChange={set('audience')}><option value="all">Everyone</option><option value="customers">Customers</option><option value="drivers">Drivers</option><option value="stores">Store owners</option></select></Field>
        <Field label="Linked store (optional)"><select className="input" value={form.store_id} onChange={set('store_id')}><option value="">None</option>{stores?.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select></Field>
        <Field label="Image" error={errors.image?.[0]}><input type="file" accept="image/*" className="input" onChange={(e) => setImage(e.target.files?.[0] || null)} /></Field>
        <Field label="Starts" error={errors.starts_at?.[0]}><input type="date" className="input" value={form.starts_at} onChange={set('starts_at')} /></Field>
        <Field label="Ends" error={errors.ends_at?.[0]}><input type="date" className="input" value={form.ends_at} onChange={set('ends_at')} /></Field>
        <div className="flex items-center gap-3 sm:col-span-2"><Toggle checked={form.is_active} onChange={(v) => setForm({ ...form, is_active: v })} label="Active" /><span className="text-sm">Visible now</span></div>
      </div>
    </Modal>
  )
}
