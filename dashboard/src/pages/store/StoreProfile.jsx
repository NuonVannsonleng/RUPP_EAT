import { useEffect, useState } from 'react'
import { ImagePlus } from 'lucide-react'
import { useAuth } from '../../context/AuthContext'
import { get, postForm } from '../../api/client'
import { useApi } from '../../hooks/useApi'
import { Card, Field, Img, PageHeader, PageLoader, Spinner, StatusBadge, Toggle, useToast } from '../../components/ui'
import { firstError } from '../../utils/format'

export default function StoreProfile() {
  const { storeId, refresh } = useAuth()
  const toast = useToast()
  const { data: campus } = useApi('/campus/locations')
  const [store, setStore] = useState(null)
  const [form, setForm] = useState(null)
  const [files, setFiles] = useState({})
  const [errors, setErrors] = useState({})
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!storeId) return
    get(`/stores/${storeId}`).then((r) => {
      const s = r.data.store
      setStore(s)
      setForm({
        name: s.name, description: s.description || '', phone: s.phone || '', location_note: s.location_note || '',
        building_id: s.building?.id || '', opening_time: s.opening_time, closing_time: s.closing_time, is_open: s.is_open,
      })
    })
  }, [storeId])

  if (!form) return <PageLoader />

  const buildings = (campus || []).flatMap((f) => f.buildings)
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })
  const err = (k) => errors[k]?.[0]

  const save = async (e) => {
    e.preventDefault()
    setSaving(true)
    setErrors({})
    try {
      const res = await postForm(`/stores/${storeId}`, { ...form, building_id: form.building_id || null, logo: files.logo, cover: files.cover }, 'PUT')
      setStore(res.data)
      setFiles({})
      toast('Store profile saved')
      refresh()
    } catch (err2) {
      setErrors(err2.errors || {})
      toast(firstError(err2), 'error')
    } finally {
      setSaving(false)
    }
  }

  const imagePicker = (key, current, label, cls) => (
    <label className="block cursor-pointer">
      <span className="label">{label}</span>
      <div className="relative">
        {files[key] ? <img src={URL.createObjectURL(files[key])} alt="" className={`${cls} object-cover`} /> : <Img src={current} className={cls} />}
        <span className="absolute bottom-2 right-2 inline-flex items-center gap-1 rounded-lg bg-white/90 px-2 py-1 text-xs font-semibold shadow"><ImagePlus className="h-3.5 w-3.5" /> Change</span>
      </div>
      <input type="file" accept="image/*" className="hidden" onChange={(e) => e.target.files?.[0] && setFiles({ ...files, [key]: e.target.files[0] })} />
      {err(key) && <span className="text-xs text-red-600">{err(key)}</span>}
    </label>
  )

  return (
    <form onSubmit={save}>
      <PageHeader title="Store profile" subtitle="What students see in the RUPP Eat app." actions={<button className="btn-accent" disabled={saving}>{saving && <Spinner className="h-4 w-4 text-white" />}Save changes</button>} />
      <div className="grid gap-6 lg:grid-cols-3">
        <Card title="Details" className="lg:col-span-2">
          <div className="space-y-4">
            <Field label="Store name" error={err('name')}><input className="input" value={form.name} onChange={set('name')} /></Field>
            <Field label="Description" error={err('description')}><textarea className="input" rows={3} value={form.description} onChange={set('description')} /></Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Building (location inside RUPP)" error={err('building_id')}>
                <select className="input" value={form.building_id} onChange={set('building_id')}>
                  <option value="">Select building</option>
                  {buildings.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
                </select>
              </Field>
              <Field label="Pickup spot" error={err('location_note')} hint="Shown to customers who pick up"><input className="input" value={form.location_note} onChange={set('location_note')} /></Field>
              <Field label="Phone" error={err('phone')}><input className="input" value={form.phone} onChange={set('phone')} /></Field>
              <div className="grid grid-cols-2 gap-3">
                <Field label="Opens" error={err('opening_time')}><input type="time" className="input" value={form.opening_time} onChange={set('opening_time')} /></Field>
                <Field label="Closes" error={err('closing_time')}><input type="time" className="input" value={form.closing_time} onChange={set('closing_time')} /></Field>
              </div>
            </div>
            <div className="flex items-center gap-3 rounded-xl bg-canvas p-3">
              <Toggle checked={form.is_open} onChange={(v) => setForm({ ...form, is_open: v })} label="Open" />
              <div>
                <p className="text-sm font-semibold">Operating status: {form.is_open ? 'Open' : 'Closed'}</p>
                <p className="text-xs text-muted">Customers can order only when open and within opening hours.</p>
              </div>
            </div>
          </div>
        </Card>
        <div className="space-y-6">
          <Card title="Branding">
            <div className="space-y-4">
              {imagePicker('cover', store.cover_url, 'Cover photo', 'h-36 w-full rounded-xl')}
              {imagePicker('logo', store.logo_url, 'Logo', 'h-20 w-20 rounded-2xl')}
            </div>
          </Card>
          <Card title="Account status">
            <div className="space-y-2 text-sm">
              <div className="flex justify-between"><span className="text-muted">Platform status</span><StatusBadge status={store.status} /></div>
              <div className="flex justify-between"><span className="text-muted">Rating</span><b>{store.rating_avg || 'New'} ({store.rating_count})</b></div>
              {store.status !== 'active' && <p className="rounded-lg bg-red-50 p-2 text-xs text-red-700">Your store is suspended by the administrator. Contact RUPP Eat support.</p>}
            </div>
          </Card>
        </div>
      </div>
    </form>
  )
}
