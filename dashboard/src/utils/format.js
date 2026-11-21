export const money = (v) =>
  new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(Number(v || 0))

export const number = (v) => new Intl.NumberFormat('en-US').format(Number(v || 0))

export const dateTime = (v) =>
  v ? new Date(v).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—'

export const date = (v) => (v ? new Date(v).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : '—')

export const time = (v) => (v ? new Date(v).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }) : '')

export function timeAgo(v) {
  if (!v) return ''
  const s = Math.floor((Date.now() - new Date(v).getTime()) / 1000)
  if (s < 60) return 'just now'
  if (s < 3600) return `${Math.floor(s / 60)} min ago`
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`
  return date(v)
}

export const STATUS = {
  pending: { label: 'Pending', tone: 'amber' },
  accepted: { label: 'Accepted', tone: 'blue' },
  preparing: { label: 'Preparing', tone: 'violet' },
  ready: { label: 'Ready', tone: 'orange' },
  driver_assigned: { label: 'Driver assigned', tone: 'blue' },
  on_the_way: { label: 'On the way', tone: 'blue' },
  delivered: { label: 'Delivered', tone: 'green' },
  picked_up: { label: 'Picked up', tone: 'green' },
  rejected: { label: 'Rejected', tone: 'red' },
  cancelled: { label: 'Cancelled', tone: 'red' },
  // delivery / generic
  searching: { label: 'Finding driver', tone: 'orange' },
  assigned: { label: 'Assigned', tone: 'blue' },
  arriving: { label: 'Arriving', tone: 'blue' },
  active: { label: 'Active', tone: 'green' },
  suspended: { label: 'Suspended', tone: 'red' },
  verified: { label: 'Verified', tone: 'green' },
  approved: { label: 'Approved', tone: 'green' },
  open: { label: 'Open', tone: 'amber' },
  resolved: { label: 'Resolved', tone: 'green' },
  paid: { label: 'Paid', tone: 'green' },
  unpaid: { label: 'Unpaid', tone: 'gray' },
}

export const statusLabel = (s) => STATUS[s]?.label || (s ? s.replaceAll('_', ' ') : '—')

export const firstError = (err) => {
  const e = err?.errors && Object.values(err.errors)[0]
  return Array.isArray(e) ? e[0] : err?.message || 'Something went wrong.'
}
