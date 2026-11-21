import { useState } from 'react'
import { Pencil, Plus, UserCheck, UserX } from 'lucide-react'
import { useApi, useDebounced } from '../../hooks/useApi'
import { patch, post, put } from '../../api/client'
import { Badge, ConfirmDialog, DataTable, ErrorState, Field, Modal, PageHeader, Pagination, SearchInput, Spinner, StatusBadge, useToast } from '../../components/ui'
import { date, firstError } from '../../utils/format'

export const ROLE_LABEL = { customer: 'Customer', driver: 'Driver', store_owner: 'Store owner', admin: 'Admin' }
const ROLE_TONE = { customer: 'gray', driver: 'blue', store_owner: 'orange', admin: 'violet' }

export default function Users() {
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [role, setRole] = useState('')
  const [status, setStatus] = useState('')
  const q = useDebounced(search)
  const { data, meta, loading, error, reload } = useApi('/admin/users', { page, search: q, role, status })
  const [editing, setEditing] = useState(null)
  const [toggling, setToggling] = useState(null)
  const toast = useToast()

  const toggleStatus = async () => {
    const next = toggling.status === 'active' ? 'suspended' : 'active'
    try {
      await patch(`/admin/users/${toggling.id}/status`, { status: next })
      toast(next === 'active' ? 'Account activated' : 'Account suspended')
      setToggling(null)
      reload(true)
    } catch (e) {
      toast(firstError(e), 'error')
    }
  }

  return (
    <>
      <PageHeader title="Users" subtitle="Students, lecturers, staff, drivers, store owners and admins." actions={<button className="btn-accent" onClick={() => setEditing({})}><Plus className="h-4 w-4" />Create account</button>} />
      <div className="card overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-line p-4 md:flex-row">
          <SearchInput value={search} onChange={(v) => { setSearch(v); setPage(1) }} placeholder="Name, email, ID or phone" />
          <select className="input md:w-44" value={role} onChange={(e) => { setRole(e.target.value); setPage(1) }}>
            <option value="">All roles</option>
            {Object.entries(ROLE_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
          <select className="input md:w-40" value={status} onChange={(e) => { setStatus(e.target.value); setPage(1) }}>
            <option value="">Any status</option><option value="active">Active</option><option value="suspended">Suspended</option>
          </select>
        </div>
        {error ? <ErrorState message={error} onRetry={reload} /> : (
          <DataTable
            loading={loading}
            rows={data}
            columns={[
              { key: 'name', label: 'Name', render: (u) => <div><p className="font-semibold">{u.name}</p><p className="text-xs text-muted">{u.email}</p></div> },
              { key: 'role', label: 'Role', render: (u) => <Badge tone={ROLE_TONE[u.role]}>{ROLE_LABEL[u.role]}{u.user_type ? ` · ${u.user_type}` : ''}</Badge> },
              { key: 'university_id', label: 'Student / staff ID', render: (u) => u.university_id || '—' },
              { key: 'phone', label: 'Phone', render: (u) => u.phone || '—' },
              { key: 'status', label: 'Status', render: (u) => <StatusBadge status={u.status} /> },
              { key: 'created_at', label: 'Joined', render: (u) => date(u.created_at) },
              { key: 'a', label: '', className: 'text-right', render: (u) => (
                <div className="flex justify-end gap-1">
                  <button className="btn-ghost p-2" title="Edit" onClick={() => setEditing(u)}><Pencil className="h-4 w-4" /></button>
                  <button className={`btn-ghost p-2 ${u.status === 'active' ? 'text-red-600' : 'text-emerald-600'}`} title={u.status === 'active' ? 'Suspend' : 'Activate'} onClick={() => setToggling(u)}>
                    {u.status === 'active' ? <UserX className="h-4 w-4" /> : <UserCheck className="h-4 w-4" />}
                  </button>
                </div>
              ) },
            ]}
          />
        )}
        <Pagination meta={meta} onPage={setPage} />
      </div>

      {editing && <UserForm user={editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); reload(true) }} />}
      <ConfirmDialog
        open={!!toggling}
        title={toggling?.status === 'active' ? `Suspend ${toggling?.name}?` : `Activate ${toggling?.name}?`}
        message={toggling?.status === 'active' ? 'They will be signed out on all devices and cannot log in until re-activated.' : 'They will be able to log in again.'}
        confirmLabel={toggling?.status === 'active' ? 'Suspend' : 'Activate'}
        danger={toggling?.status === 'active'}
        onClose={() => setToggling(null)}
        onConfirm={toggleStatus}
      />
    </>
  )
}

/** Create / edit any account, including role assignment and driver details. */
export function UserForm({ user, onClose, onSaved, defaultRole = 'customer' }) {
  const isNew = !user.id
  const toast = useToast()
  const [form, setForm] = useState({
    name: user.name || '', email: user.email || '', phone: user.phone || '', university_id: user.university_id || '',
    role: user.role || defaultRole, user_type: user.user_type || 'student', password: '',
    vehicle_type: user.driver_profile?.vehicle_type || 'motorbike', plate_number: user.driver_profile?.plate_number || '',
    verification_status: user.driver_profile?.verification_status || (isNew ? 'verified' : ''),
  })
  const [errors, setErrors] = useState({})
  const [saving, setSaving] = useState(false)
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })
  const err = (k) => errors[k]?.[0]

  const save = async () => {
    setSaving(true)
    setErrors({})
    const body = { ...form }
    if (!body.password) delete body.password
    if (body.role !== 'customer') delete body.user_type
    if (body.role !== 'driver') { delete body.vehicle_type; delete body.plate_number; delete body.verification_status }
    if (!body.university_id) body.university_id = null
    try {
      if (isNew) await post('/admin/users', body)
      else await put(`/admin/users/${user.id}`, body)
      toast(isNew ? 'Account created' : 'User updated')
      onSaved()
    } catch (e) {
      setErrors(e.errors || {})
      toast(firstError(e), 'error')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal open onClose={onClose} title={isNew ? 'Create account' : `Edit ${user.name}`}
      footer={<><button className="btn-outline" onClick={onClose}>Cancel</button><button className="btn-primary" onClick={save} disabled={saving}>{saving && <Spinner className="h-4 w-4 text-white" />}Save</button></>}>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Full name" error={err('name')}><input className="input" value={form.name} onChange={set('name')} /></Field>
        <Field label="Email" error={err('email')}><input className="input" type="email" value={form.email} onChange={set('email')} /></Field>
        <Field label="Role" error={err('role')}>
          <select className="input" value={form.role} onChange={set('role')}>
            {Object.entries(ROLE_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </Field>
        {form.role === 'customer' && (
          <Field label="Type" error={err('user_type')}>
            <select className="input" value={form.user_type} onChange={set('user_type')}>
              <option value="student">Student</option><option value="lecturer">Lecturer</option><option value="staff">Staff</option>
            </select>
          </Field>
        )}
        <Field label="Student / staff ID" error={err('university_id')}><input className="input" value={form.university_id} onChange={set('university_id')} /></Field>
        <Field label="Phone" error={err('phone')}><input className="input" value={form.phone} onChange={set('phone')} /></Field>
        <Field label={isNew ? 'Password' : 'New password (optional)'} error={err('password')} hint="Min 8 characters, letters and numbers"><input className="input" type="password" value={form.password} onChange={set('password')} autoComplete="new-password" /></Field>
        {form.role === 'driver' && (
          <>
            <Field label="Vehicle" error={err('vehicle_type')}>
              <select className="input" value={form.vehicle_type} onChange={set('vehicle_type')}>
                <option value="motorbike">Motorbike</option><option value="bicycle">Bicycle</option><option value="walking">On foot</option>
              </select>
            </Field>
            <Field label="Plate number" error={err('plate_number')}><input className="input" value={form.plate_number} onChange={set('plate_number')} /></Field>
            <Field label="Verification" error={err('verification_status')}>
              <select className="input" value={form.verification_status} onChange={set('verification_status')}>
                <option value="pending">Pending</option><option value="verified">Verified</option><option value="rejected">Rejected</option>
              </select>
            </Field>
          </>
        )}
      </div>
    </Modal>
  )
}
