import { useState } from 'react'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import { useApi } from '../../hooks/useApi'
import { del, post, put } from '../../api/client'
import { ConfirmDialog, DataTable, Field, Modal, PageHeader, Spinner, StatusBadge, Toggle, useToast } from '../../components/ui'
import { firstError } from '../../utils/format'

const ICONS = ['rice_bowl', 'ramen_dining', 'lunch_dining', 'fastfood', 'local_cafe', 'local_drink', 'icecream', 'eco', 'egg_alt', 'bakery_dining', 'local_pizza']

export default function Categories() {
  const { data, loading, reload } = useApi('/admin/categories')
  const [editing, setEditing] = useState(null)
  const [deleting, setDeleting] = useState(null)
  const toast = useToast()

  const remove = async () => {
    try { await del(`/admin/categories/${deleting.id}`); toast('Category deleted'); setDeleting(null); reload(true) } catch (e) { toast(firstError(e), 'error') }
  }

  return (
    <>
      <PageHeader title="Food categories" subtitle="Shown as filters on the mobile home screen and used by stores to group menus." actions={<button className="btn-accent" onClick={() => setEditing({})}><Plus className="h-4 w-4" />Add category</button>} />
      <div className="card overflow-hidden">
        <DataTable loading={loading} rows={data} columns={[
          { key: 'sort_order', label: 'Order' },
          { key: 'name', label: 'Name', render: (c) => <span className="font-semibold">{c.name}</span> },
          { key: 'icon', label: 'App icon', render: (c) => <code className="text-xs">{c.icon}</code> },
          { key: 'products_count', label: 'Products' },
          { key: 'is_active', label: 'Status', render: (c) => <StatusBadge status={c.is_active ? 'active' : 'suspended'} label={c.is_active ? 'Visible' : 'Hidden'} /> },
          { key: 'a', label: '', className: 'text-right', render: (c) => <div className="flex justify-end gap-1">
            <button className="btn-ghost p-2" onClick={() => setEditing(c)}><Pencil className="h-4 w-4" /></button>
            <button className="btn-ghost p-2 text-red-600" onClick={() => setDeleting(c)}><Trash2 className="h-4 w-4" /></button>
          </div> },
        ]} />
      </div>
      {editing && <CategoryForm category={editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); reload(true) }} />}
      <ConfirmDialog open={!!deleting} title={`Delete ${deleting?.name}?`} message="Products in this category will become uncategorised." confirmLabel="Delete" danger onClose={() => setDeleting(null)} onConfirm={remove} />
    </>
  )
}

function CategoryForm({ category, onClose, onSaved }) {
  const isNew = !category.id
  const toast = useToast()
  const [form, setForm] = useState({ name: category.name || '', icon: category.icon || 'fastfood', sort_order: category.sort_order ?? 0, is_active: category.is_active ?? true })
  const [errors, setErrors] = useState({})
  const [saving, setSaving] = useState(false)
  const save = async () => {
    setSaving(true)
    try {
      if (isNew) await post('/admin/categories', form); else await put(`/admin/categories/${category.id}`, form)
      toast('Saved'); onSaved()
    } catch (e) { setErrors(e.errors || {}); toast(firstError(e), 'error') } finally { setSaving(false) }
  }
  return (
    <Modal open onClose={onClose} size="sm" title={isNew ? 'Add category' : 'Edit category'}
      footer={<><button className="btn-outline" onClick={onClose}>Cancel</button><button className="btn-primary" disabled={saving} onClick={save}>{saving && <Spinner className="h-4 w-4 text-white" />}Save</button></>}>
      <div className="space-y-4">
        <Field label="Name" error={errors.name?.[0]}><input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></Field>
        <Field label="Icon (Material icon name)"><select className="input" value={form.icon} onChange={(e) => setForm({ ...form, icon: e.target.value })}>{ICONS.map((i) => <option key={i}>{i}</option>)}</select></Field>
        <Field label="Sort order"><input type="number" min="0" className="input" value={form.sort_order} onChange={(e) => setForm({ ...form, sort_order: e.target.value })} /></Field>
        <div className="flex items-center gap-3"><Toggle checked={form.is_active} onChange={(v) => setForm({ ...form, is_active: v })} label="Visible" /><span className="text-sm">Visible in the app</span></div>
      </div>
    </Modal>
  )
}
