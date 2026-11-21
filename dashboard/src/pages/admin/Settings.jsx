import { useEffect, useState } from 'react'
import { useApi } from '../../hooks/useApi'
import { put } from '../../api/client'
import { Card, ErrorState, PageHeader, PageLoader, Spinner, Toggle, useToast } from '../../components/ui'
import { firstError } from '../../utils/format'

const LABELS = {
  delivery_fee: 'Delivery fee (USD)',
  free_delivery_threshold: 'Free delivery from subtotal (USD, 0 = off)',
  delivery_enabled: 'Classroom delivery enabled',
  max_active_deliveries_per_driver: 'Max deliveries a driver can carry at once',
  min_order_amount: 'Minimum order subtotal (USD)',
  support_phone: 'Support phone',
  support_email: 'Support email',
}

export default function SettingsPage() {
  const { data, loading, error, reload } = useApi('/admin/settings')
  const [values, setValues] = useState({})
  const [saving, setSaving] = useState(false)
  const toast = useToast()

  useEffect(() => {
    if (data) setValues(Object.fromEntries(data.map((s) => [s.key, s.value])))
  }, [data])

  if (error) return <ErrorState message={error} onRetry={reload} />
  if (loading || !data) return <PageLoader />

  const groups = data.reduce((acc, s) => ({ ...acc, [s.group]: [...(acc[s.group] || []), s] }), {})

  const save = async () => {
    setSaving(true)
    try {
      await put('/admin/settings', { settings: values })
      toast('Settings saved')
      reload(true)
    } catch (e) { toast(firstError(e), 'error') } finally { setSaving(false) }
  }

  return (
    <>
      <PageHeader title="System settings" subtitle="Delivery fees and operational rules. Changes apply immediately to new orders." actions={<button className="btn-accent" onClick={save} disabled={saving}>{saving && <Spinner className="h-4 w-4 text-white" />}Save settings</button>} />
      <div className="grid gap-6 lg:grid-cols-2">
        {Object.entries(groups).map(([group, items]) => (
          <Card key={group} title={<span className="capitalize">{group}</span>}>
            <div className="space-y-5">
              {items.map((s) => (
                <div key={s.key}>
                  {s.type === 'boolean' ? (
                    <div className="flex items-center justify-between gap-4">
                      <div><p className="text-sm font-semibold">{LABELS[s.key] || s.key}</p><p className="text-xs text-muted">{s.description}</p></div>
                      <Toggle checked={!!values[s.key]} onChange={(v) => setValues({ ...values, [s.key]: v })} label={s.key} />
                    </div>
                  ) : (
                    <label className="block">
                      <span className="label">{LABELS[s.key] || s.key}</span>
                      <input className="input" type={s.type === 'number' ? 'number' : 'text'} step="0.01" min="0" value={values[s.key] ?? ''} onChange={(e) => setValues({ ...values, [s.key]: e.target.value })} />
                      <span className="mt-1 block text-xs text-muted">{s.description}</span>
                    </label>
                  )}
                </div>
              ))}
            </div>
          </Card>
        ))}
        <Card title="Payments">
          <p className="text-sm">Cash on delivery and cash on pickup are active. Payment is marked <b>paid</b> only when the driver or store confirms the hand-over.</p>
          <p className="mt-3 text-sm text-muted">Bakong KHQR is prepared as a separate integration (<code>KHQR_ENABLED</code> in the backend <code>.env</code>). It stays disabled until real Bakong verification is connected, so no payment is ever marked successful without verification.</p>
        </Card>
      </div>
    </>
  )
}
