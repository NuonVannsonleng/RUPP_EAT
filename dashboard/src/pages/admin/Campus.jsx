import { useState } from 'react'
import { Building2, ChevronDown, ChevronRight, DoorOpen, Layers, Pencil, Plus, Trash2 } from 'lucide-react'
import { useApi } from '../../hooks/useApi'
import { del, post, put } from '../../api/client'
import { Badge, ConfirmDialog, ErrorState, Field, Modal, PageHeader, PageLoader, Spinner, Toggle, useToast } from '../../components/ui'
import { firstError } from '../../utils/format'

/**
 * Faculties → buildings → floors → classrooms. Classrooms are the delivery
 * destinations customers pick at checkout and drivers see on their screen.
 */
export default function Campus() {
  const { data, loading, error, reload } = useApi('/admin/campus')
  const [open, setOpen] = useState({})
  const [form, setForm] = useState(null) // { type, parent, item }
  const [deleting, setDeleting] = useState(null)
  const toast = useToast()

  if (error) return <ErrorState message={error} onRetry={reload} />
  if (loading || !data) return <PageLoader />

  const toggle = (id) => setOpen((o) => ({ ...o, [id]: !o[id] }))
  const remove = async () => {
    try {
      await del(`/admin/${deleting.type}s/${deleting.item.id}`)
      toast('Deleted')
      setDeleting(null)
      reload(true)
    } catch (e) { toast(firstError(e), 'error') }
  }

  const actions = (type, item, parent) => (
    <span className="flex gap-1" onClick={(e) => e.stopPropagation()}>
      <button className="btn-ghost p-1.5" title="Edit" onClick={() => setForm({ type, item, parent })}><Pencil className="h-3.5 w-3.5" /></button>
      <button className="btn-ghost p-1.5 text-red-600" title="Delete" onClick={() => setDeleting({ type, item })}><Trash2 className="h-3.5 w-3.5" /></button>
    </span>
  )

  const buildingBlock = (b) => (
    <div key={b.id} className="rounded-xl border border-line">
      <div className="flex cursor-pointer items-center gap-2 px-3 py-2.5" onClick={() => toggle(b.id)}>
        {open[b.id] ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
        <Building2 className="h-4 w-4 text-brand-600" />
        <span className="flex-1 text-sm font-semibold">{b.name} <span className="text-muted">({b.code})</span></span>
        {!b.is_active && <Badge tone="red">Inactive</Badge>}
        <Badge>{b.floors.length} floors</Badge>
        {actions('building', b)}
      </div>
      {open[b.id] && (
        <div className="space-y-2 border-t border-line bg-canvas/50 p-3">
          {b.floors.map((fl) => (
            <div key={fl.id} className="rounded-lg bg-white p-3 ring-1 ring-line">
              <div className="mb-2 flex items-center gap-2">
                <Layers className="h-4 w-4 text-accent-500" />
                <span className="flex-1 text-sm font-semibold">{fl.label || `Floor ${fl.number}`}</span>
                <button className="btn-ghost btn-sm" onClick={() => setForm({ type: 'classroom', parent: fl })}><Plus className="h-3.5 w-3.5" />Room</button>
                {actions('floor', fl, b)}
              </div>
              <div className="flex flex-wrap gap-2">
                {fl.classrooms.map((c) => (
                  <button key={c.id} onClick={() => setForm({ type: 'classroom', item: c, parent: fl })}
                    className={`inline-flex items-center gap-1 rounded-lg border px-2.5 py-1 text-xs font-medium ${c.is_deliverable ? 'border-line bg-white' : 'border-dashed border-red-300 text-red-600'}`}>
                    <DoorOpen className="h-3 w-3" />{c.name}
                  </button>
                ))}
                {!fl.classrooms.length && <span className="text-xs text-muted">No rooms yet</span>}
              </div>
            </div>
          ))}
          <button className="btn-outline btn-sm" onClick={() => setForm({ type: 'floor', parent: b })}><Plus className="h-3.5 w-3.5" />Add floor</button>
        </div>
      )}
    </div>
  )

  return (
    <>
      <PageHeader title="Campus locations" subtitle="Delivery is designed around RUPP buildings and classrooms, not GPS addresses." actions={<>
        <button className="btn-outline" onClick={() => setForm({ type: 'building' })}><Plus className="h-4 w-4" />Building</button>
        <button className="btn-accent" onClick={() => setForm({ type: 'faculty' })}><Plus className="h-4 w-4" />Faculty</button>
      </>} />
      <div className="space-y-4">
        {data.faculties.map((f) => (
          <div key={f.id} className="card p-4">
            <div className="mb-3 flex items-center gap-2">
              <h3 className="flex-1 font-bold">{f.name} <span className="text-sm font-medium text-muted">· {f.code}</span></h3>
              {!f.is_active && <Badge tone="red">Inactive</Badge>}
              <button className="btn-ghost btn-sm" onClick={() => setForm({ type: 'building', parent: f })}><Plus className="h-3.5 w-3.5" />Building</button>
              {actions('faculty', f)}
            </div>
            <div className="space-y-2">{f.buildings.map(buildingBlock)}{!f.buildings.length && <p className="text-sm text-muted">No buildings.</p>}</div>
          </div>
        ))}
        {data.unassigned_buildings.length > 0 && (
          <div className="card p-4"><h3 className="mb-3 font-bold">Other buildings</h3><div className="space-y-2">{data.unassigned_buildings.map(buildingBlock)}</div></div>
        )}
      </div>
      {form && <CampusForm {...form} faculties={data.faculties} onClose={() => setForm(null)} onSaved={() => { setForm(null); reload(true) }} />}
      <ConfirmDialog open={!!deleting} title={`Delete ${deleting?.item.name || deleting?.item.label || 'item'}?`} message="Past orders keep their saved delivery location." confirmLabel="Delete" danger onClose={() => setDeleting(null)} onConfirm={remove} />
    </>
  )
}

function CampusForm({ type, item, parent, faculties, onClose, onSaved }) {
  const isNew = !item
  const toast = useToast()
  const [form, setForm] = useState(() => ({
    faculty: { name: item?.name || '', code: item?.code || '', description: item?.description || '', is_active: item?.is_active ?? true },
    building: { name: item?.name || '', code: item?.code || '', faculty_id: item?.faculty_id || parent?.id || '', is_active: item?.is_active ?? true, floors: 3 },
    floor: { number: item?.number ?? (parent?.floors?.length || 0) + 1, label: item?.label || '' },
    classroom: { name: item?.name || '', type: item?.type || 'classroom', is_deliverable: item?.is_deliverable ?? true },
  })[type])
  const [errors, setErrors] = useState({})
  const [saving, setSaving] = useState(false)
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })
  const err = (k) => errors[k]?.[0]

  const save = async () => {
    setSaving(true)
    try {
      const body = { ...form }
      if (type === 'floor' && isNew) body.building_id = parent.id
      if (type === 'classroom' && isNew) body.floor_id = parent.id
      if (type === 'building') { body.faculty_id = body.faculty_id || null; if (!isNew) delete body.floors }
      if (isNew) await post(`/admin/${type === 'faculty' ? 'faculties' : `${type}s`}`, body)
      else await put(`/admin/${type === 'faculty' ? 'faculties' : `${type}s`}/${item.id}`, body)
      toast('Saved')
      onSaved()
    } catch (e) {
      setErrors(e.errors || {})
      toast(firstError(e), 'error')
    } finally { setSaving(false) }
  }

  return (
    <Modal open onClose={onClose} size="sm" title={`${isNew ? 'Add' : 'Edit'} ${type}`}
      footer={<><button className="btn-outline" onClick={onClose}>Cancel</button><button className="btn-primary" disabled={saving} onClick={save}>{saving && <Spinner className="h-4 w-4 text-white" />}Save</button></>}>
      <div className="space-y-4">
        {(type === 'faculty' || type === 'building') && <>
          <Field label="Name" error={err('name')}><input className="input" value={form.name} onChange={set('name')} /></Field>
          <Field label="Code" error={err('code')}><input className="input" value={form.code} onChange={set('code')} placeholder={type === 'faculty' ? 'FE' : 'ENG'} /></Field>
        </>}
        {type === 'building' && <>
          <Field label="Faculty" error={err('faculty_id')}>
            <select className="input" value={form.faculty_id} onChange={set('faculty_id')}>
              <option value="">None (shared building)</option>
              {faculties.map((f) => <option key={f.id} value={f.id}>{f.name}</option>)}
            </select>
          </Field>
          {isNew && <Field label="Create floors" hint="Floors 1..N are created automatically" error={err('floors')}><input type="number" min="1" max="20" className="input" value={form.floors} onChange={set('floors')} /></Field>}
        </>}
        {type === 'floor' && <>
          <Field label="Floor number" error={err('number')}><input type="number" className="input" value={form.number} onChange={set('number')} /></Field>
          <Field label="Label" error={err('label')}><input className="input" value={form.label} onChange={set('label')} placeholder="e.g. Ground floor" /></Field>
        </>}
        {type === 'classroom' && <>
          <Field label="Room name" error={err('name')}><input className="input" value={form.name} onChange={set('name')} placeholder="Room 305" /></Field>
          <Field label="Type" error={err('type')}>
            <select className="input" value={form.type} onChange={set('type')}>
              {['classroom', 'lab', 'office', 'hall', 'library', 'other'].map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
        </>}
        {'is_active' in form && <div className="flex items-center gap-3"><Toggle checked={form.is_active} onChange={(v) => setForm({ ...form, is_active: v })} label="Active" /><span className="text-sm">Active</span></div>}
        {'is_deliverable' in form && <div className="flex items-center gap-3"><Toggle checked={form.is_deliverable} onChange={(v) => setForm({ ...form, is_deliverable: v })} label="Deliverable" /><span className="text-sm">Customers can choose this room for delivery</span></div>}
      </div>
    </Modal>
  )
}
