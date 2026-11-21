import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { CheckCircle2, Loader2 } from 'lucide-react'
import { get, post } from '../api/client'
import { Field } from '../components/ui'
import { firstError } from '../utils/format'

/** Public form for new campus food stores. Admins review it under Store applications. */
export default function ApplyStore() {
  const [buildings, setBuildings] = useState([])
  const [form, setForm] = useState({ applicant_name: '', applicant_email: '', applicant_phone: '', store_name: '', description: '', building_id: '', location_note: '' })
  const [errors, setErrors] = useState({})
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [done, setDone] = useState(false)

  useEffect(() => {
    get('/campus/locations').then((res) => setBuildings(res.data.flatMap((f) => f.buildings.map((b) => ({ ...b, faculty: f.name }))))).catch(() => {})
  }, [])

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setErrors({})
    setError('')
    try {
      await post('/store-applications', { ...form, building_id: form.building_id || null })
      setDone(true)
    } catch (err) {
      setErrors(err.errors || {})
      setError(firstError(err))
    } finally {
      setLoading(false)
    }
  }

  const err = (k) => errors[k]?.[0]

  return (
    <div className="min-h-full bg-canvas px-4 py-10">
      <div className="mx-auto max-w-xl">
        <Link to="/login" className="text-sm font-semibold text-brand-600 hover:underline">← Back to login</Link>
        <div className="card mt-4 p-6 sm:p-8">
          {done ? (
            <div className="py-8 text-center">
              <CheckCircle2 className="mx-auto h-14 w-14 text-emerald-500" />
              <h1 className="mt-4 text-2xl font-extrabold">Application submitted</h1>
              <p className="mt-2 text-muted">The RUPP Eat team will review it and contact you at {form.applicant_email}.</p>
            </div>
          ) : (
            <form onSubmit={submit} className="space-y-4">
              <div>
                <h1 className="text-2xl font-extrabold">Open your store on RUPP Eat</h1>
                <p className="mt-1 text-sm text-muted">For new food stores and restaurants inside Royal University of Phnom Penh.</p>
              </div>
              {error && <div className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Your name" error={err('applicant_name')}><input className="input" value={form.applicant_name} onChange={set('applicant_name')} required /></Field>
                <Field label="Phone" error={err('applicant_phone')}><input className="input" value={form.applicant_phone} onChange={set('applicant_phone')} required /></Field>
              </div>
              <Field label="Email" error={err('applicant_email')}><input className="input" type="email" value={form.applicant_email} onChange={set('applicant_email')} required /></Field>
              <Field label="Store name" error={err('store_name')}><input className="input" value={form.store_name} onChange={set('store_name')} required /></Field>
              <Field label="What do you sell?" error={err('description')}><textarea className="input" rows={3} value={form.description} onChange={set('description')} /></Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Building" error={err('building_id')}>
                  <select className="input" value={form.building_id} onChange={set('building_id')}>
                    <option value="">Select building</option>
                    {buildings.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
                  </select>
                </Field>
                <Field label="Exact spot" error={err('location_note')}><input className="input" value={form.location_note} onChange={set('location_note')} placeholder="e.g. Ground floor, near stairs" /></Field>
              </div>
              <button className="btn-accent w-full py-3" disabled={loading}>{loading && <Loader2 className="h-4 w-4 animate-spin" />} Submit application</button>
            </form>
          )}
        </div>
      </div>
    </div>
  )
}
