import { useState } from 'react'
import { Check, Copy, FileCheck2, X } from 'lucide-react'
import { useApi } from '../../hooks/useApi'
import { post } from '../../api/client'
import { ConfirmDialog, DataTable, EmptyState, Field, Modal, PageHeader, Pagination, StatusBadge, Tabs, useToast } from '../../components/ui'
import { date, firstError } from '../../utils/format'

export default function Applications() {
  const [status, setStatus] = useState('pending')
  const [page, setPage] = useState(1)
  const { data, meta, loading, reload } = useApi('/admin/store-applications', { status, page })
  const [approving, setApproving] = useState(null)
  const [rejecting, setRejecting] = useState(null)
  const [note, setNote] = useState('')
  const [hours, setHours] = useState({ opening_time: '07:00', closing_time: '17:00' })
  const [result, setResult] = useState(null)
  const [busy, setBusy] = useState(false)
  const toast = useToast()

  const approve = async () => {
    setBusy(true)
    try {
      const res = await post(`/admin/store-applications/${approving.id}/approve`, { ...hours, note })
      setApproving(null)
      setResult(res.data)
      reload(true)
    } catch (e) { toast(firstError(e), 'error') } finally { setBusy(false) }
  }

  const reject = async () => {
    setBusy(true)
    try {
      await post(`/admin/store-applications/${rejecting.id}/reject`, { note })
      toast('Application rejected')
      setRejecting(null)
      setNote('')
      reload(true)
    } catch (e) { toast(firstError(e), 'error') } finally { setBusy(false) }
  }

  return (
    <>
      <PageHeader title="Store applications" subtitle="New campus food stores applying to join RUPP Eat (public form at /apply)." />
      <div className="mb-4"><Tabs value={status} onChange={(v) => { setStatus(v); setPage(1) }} tabs={[{ value: 'pending', label: 'Pending' }, { value: 'approved', label: 'Approved' }, { value: 'rejected', label: 'Rejected' }, { value: '', label: 'All' }]} /></div>
      <div className="card overflow-hidden">
        <DataTable
          loading={loading}
          rows={data}
          empty={<EmptyState icon={FileCheck2} title="No applications" />}
          columns={[
            { key: 'store', label: 'Store', render: (a) => <div><p className="font-semibold">{a.store_name}</p><p className="max-w-xs truncate text-xs text-muted">{a.description}</p></div> },
            { key: 'applicant', label: 'Applicant', render: (a) => <div className="text-sm"><p>{a.applicant_name}</p><p className="text-xs text-muted">{a.applicant_email} · {a.applicant_phone}</p></div> },
            { key: 'location', label: 'Location', render: (a) => <span className="text-sm">{a.building?.name}{a.location_note && <span className="text-muted"> · {a.location_note}</span>}</span> },
            { key: 'created_at', label: 'Applied', render: (a) => date(a.created_at) },
            { key: 'status', label: 'Status', render: (a) => <div><StatusBadge status={a.status} />{a.review_note && <p className="mt-1 text-xs text-muted">{a.review_note}</p>}</div> },
            { key: 'a', label: '', className: 'text-right', render: (a) => a.status === 'pending' && (
              <div className="flex justify-end gap-2">
                <button className="btn-primary btn-sm" onClick={() => { setNote(''); setApproving(a) }}><Check className="h-4 w-4" />Approve</button>
                <button className="btn-outline btn-sm text-red-600" onClick={() => { setNote(''); setRejecting(a) }}><X className="h-4 w-4" />Reject</button>
              </div>
            ) },
          ]}
        />
        <Pagination meta={meta} onPage={setPage} />
      </div>

      <ConfirmDialog open={!!approving} title={`Approve ${approving?.store_name}?`} message="Creates the store (closed until the owner opens it) and a Store owner account if this email has none." confirmLabel="Approve & create store" loading={busy} onClose={() => setApproving(null)} onConfirm={approve}>
        <div className="mt-4 grid grid-cols-2 gap-3">
          <Field label="Opens"><input type="time" className="input" value={hours.opening_time} onChange={(e) => setHours({ ...hours, opening_time: e.target.value })} /></Field>
          <Field label="Closes"><input type="time" className="input" value={hours.closing_time} onChange={(e) => setHours({ ...hours, closing_time: e.target.value })} /></Field>
        </div>
        <input className="input mt-3" placeholder="Note (optional)" value={note} onChange={(e) => setNote(e.target.value)} />
      </ConfirmDialog>

      <ConfirmDialog open={!!rejecting} title={`Reject ${rejecting?.store_name}?`} confirmLabel="Reject" danger loading={busy} onClose={() => setRejecting(null)} onConfirm={reject}>
        <Field label="Reason (required)"><input className="input mt-2" value={note} onChange={(e) => setNote(e.target.value)} placeholder="e.g. Location not available" /></Field>
      </ConfirmDialog>

      <Modal open={!!result} onClose={() => setResult(null)} title="Store created" size="sm" footer={<button className="btn-primary" onClick={() => setResult(null)}>Done</button>}>
        <p className="text-sm"><b>{result?.store?.name}</b> is now on RUPP Eat.</p>
        <p className="mt-3 text-sm">Owner login: <b>{result?.owner_email}</b></p>
        {result?.temporary_password ? (
          <div className="mt-3 rounded-xl bg-accent-50 p-3 text-sm">
            <p>Temporary password (shown once — give it to the owner privately):</p>
            <div className="mt-2 flex items-center gap-2">
              <code className="rounded bg-white px-2 py-1 font-bold">{result.temporary_password}</code>
              <button className="btn-ghost p-1.5" onClick={() => navigator.clipboard?.writeText(result.temporary_password)} title="Copy"><Copy className="h-4 w-4" /></button>
            </div>
          </div>
        ) : <p className="mt-2 text-sm text-muted">The owner already had an account and can sign in with their existing password.</p>}
      </Modal>
    </>
  )
}
