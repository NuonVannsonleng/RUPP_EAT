import { useState } from 'react'
import { ImagePlus, Pencil, Plus, Trash2, UtensilsCrossed } from 'lucide-react'
import { useAuth } from '../../context/AuthContext'
import { useApi, useDebounced } from '../../hooks/useApi'
import { del, postForm } from '../../api/client'
import { Badge, ConfirmDialog, DataTable, EmptyState, ErrorState, Field, Img, Modal, PageHeader, SearchInput, Spinner, Toggle, useToast } from '../../components/ui'
import { firstError, money } from '../../utils/format'

export default function Products() {
  const { storeId } = useAuth()
  const toast = useToast()
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState('')
  const [availability, setAvailability] = useState('')
  const q = useDebounced(search)
  const { data, loading, error, reload } = useApi(`/stores/${storeId}/products`, { manage: 1, search: q, category, availability, sort: 'name', per_page: 100 }, { enabled: !!storeId })
  const { data: categories } = useApi('/categories')
  const [editing, setEditing] = useState(null) // product or {} for new
  const [deleting, setDeleting] = useState(null)

  const toggleAvailable = async (p) => {
    try {
      await postForm(`/products/${p.id}`, { is_available: !p.is_available }, 'PUT')
      toast(`${p.name} is now ${p.is_available ? 'unavailable' : 'available'}`)
      reload(true)
    } catch (e) {
      toast(firstError(e), 'error')
    }
  }

  const remove = async () => {
    try {
      await del(`/products/${deleting.id}`)
      toast('Product deleted')
      setDeleting(null)
      reload(true)
    } catch (e) {
      toast(firstError(e), 'error')
    }
  }

  return (
    <>
      <PageHeader title="Menu & products" subtitle="Prices and stock are enforced by the server at checkout." actions={<button className="btn-accent" onClick={() => setEditing({})}><Plus className="h-4 w-4" /> Add product</button>} />
      <div className="card overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-line p-4 md:flex-row">
          <SearchInput value={search} onChange={setSearch} placeholder="Search menu" />
          <select className="input md:w-52" value={category} onChange={(e) => setCategory(e.target.value)}>
            <option value="">All categories</option>
            {categories?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          <select className="input md:w-48" value={availability} onChange={(e) => setAvailability(e.target.value)}>
            <option value="">All items</option>
            <option value="unavailable">Unavailable only</option>
            <option value="low_stock">Low stock (≤ 5)</option>
          </select>
        </div>
        {error ? <ErrorState message={error} onRetry={reload} /> : (
          <DataTable
            loading={loading}
            rows={data}
            empty={<EmptyState icon={UtensilsCrossed} title="No products yet" message="Add your first menu item." action={<button className="btn-accent" onClick={() => setEditing({})}>Add product</button>} />}
            columns={[
              { key: 'name', label: 'Product', render: (p) => (
                <div className="flex items-center gap-3">
                  <Img src={p.image_url} className="h-12 w-12 shrink-0 rounded-xl" />
                  <div className="min-w-0">
                    <p className="font-semibold">{p.name}</p>
                    <p className="max-w-xs truncate text-xs text-muted">{p.description}</p>
                  </div>
                </div>
              ) },
              { key: 'category', label: 'Category', render: (p) => p.category?.name || <span className="text-muted">—</span> },
              { key: 'price', label: 'Price', render: (p) => <span className="font-semibold">{money(p.price)}</span> },
              { key: 'stock', label: 'Stock', render: (p) => p.stock_quantity == null ? <span className="text-muted">Not tracked</span> : <Badge tone={p.stock_quantity === 0 ? 'red' : p.stock_quantity <= 5 ? 'orange' : 'gray'}>{p.stock_quantity} left</Badge> },
              { key: 'sold', label: 'Sold', render: (p) => p.sold_count },
              { key: 'available', label: 'Available', render: (p) => <Toggle checked={p.is_available} onChange={() => toggleAvailable(p)} label="Available" /> },
              { key: 'actions', label: '', className: 'text-right', render: (p) => (
                <div className="flex justify-end gap-1">
                  <button className="btn-ghost p-2" onClick={() => setEditing(p)} title="Edit"><Pencil className="h-4 w-4" /></button>
                  <button className="btn-ghost p-2 text-red-600" onClick={() => setDeleting(p)} title="Delete"><Trash2 className="h-4 w-4" /></button>
                </div>
              ) },
            ]}
          />
        )}
      </div>

      {editing && <ProductForm product={editing} storeId={storeId} categories={categories || []} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); reload(true) }} />}
      <ConfirmDialog open={!!deleting} title={`Delete ${deleting?.name}?`} message="It disappears from the menu. Past orders keep their history." confirmLabel="Delete" danger onClose={() => setDeleting(null)} onConfirm={remove} />
    </>
  )
}

function ProductForm({ product, storeId, categories, onClose, onSaved }) {
  const isNew = !product.id
  const toast = useToast()
  const [form, setForm] = useState({
    name: product.name || '',
    description: product.description || '',
    price: product.price ?? '',
    category_id: product.category?.id || '',
    stock_quantity: product.stock_quantity ?? '',
    is_available: product.is_available ?? true,
  })
  const [image, setImage] = useState(null)
  const [preview, setPreview] = useState(product.image_url || null)
  const [errors, setErrors] = useState({})
  const [saving, setSaving] = useState(false)
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })

  const save = async () => {
    setSaving(true)
    setErrors({})
    try {
      const fields = { ...form, image: image || undefined }
      if (isNew) await postForm('/products', { ...fields, store_id: storeId })
      else await postForm(`/products/${product.id}`, fields, 'PUT')
      toast(isNew ? 'Product added' : 'Product updated')
      onSaved()
    } catch (e) {
      setErrors(e.errors || {})
      toast(firstError(e), 'error')
    } finally {
      setSaving(false)
    }
  }

  const err = (k) => errors[k]?.[0]

  return (
    <Modal open onClose={onClose} title={isNew ? 'Add product' : `Edit ${product.name}`}
      footer={<><button className="btn-outline" onClick={onClose}>Cancel</button><button className="btn-primary" onClick={save} disabled={saving}>{saving && <Spinner className="h-4 w-4 text-white" />}Save</button></>}>
      <div className="space-y-4">
        <label className="flex cursor-pointer items-center gap-4">
          {preview ? <img src={preview} alt="" className="h-24 w-32 rounded-xl object-cover" /> : <div className="flex h-24 w-32 items-center justify-center rounded-xl border-2 border-dashed border-line text-muted"><ImagePlus /></div>}
          <div>
            <span className="btn-outline btn-sm">Upload photo</span>
            <p className="mt-1 text-xs text-muted">JPG, PNG or WebP, up to 4 MB</p>
            {err('image') && <p className="text-xs text-red-600">{err('image')}</p>}
          </div>
          <input type="file" accept="image/jpeg,image/png,image/webp" className="hidden" onChange={(e) => {
            const f = e.target.files?.[0]
            if (f) { setImage(f); setPreview(URL.createObjectURL(f)) }
          }} />
        </label>
        <Field label="Name" error={err('name')}><input className="input" value={form.name} onChange={set('name')} /></Field>
        <Field label="Description" error={err('description')}><textarea className="input" rows={2} value={form.description} onChange={set('description')} /></Field>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Price (USD)" error={err('price')}><input className="input" type="number" step="0.05" min="0" value={form.price} onChange={set('price')} /></Field>
          <Field label="Stock" error={err('stock_quantity')} hint="Empty = not tracked"><input className="input" type="number" min="0" value={form.stock_quantity} onChange={set('stock_quantity')} /></Field>
          <Field label="Category" error={err('category_id')}>
            <select className="input" value={form.category_id} onChange={set('category_id')}>
              <option value="">None</option>
              {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </Field>
        </div>
        <div className="flex items-center gap-3">
          <Toggle checked={form.is_available} onChange={(v) => setForm({ ...form, is_available: v })} label="Available" />
          <span className="text-sm font-medium">Available for ordering</span>
        </div>
      </div>
    </Modal>
  )
}
