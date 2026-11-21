import { useState } from 'react'
import { useApi, useDebounced } from '../../hooks/useApi'
import { Badge, DataTable, PageHeader, Pagination, SearchInput } from '../../components/ui'
import { dateTime } from '../../utils/format'

const ACTIONS = ['order', 'delivery', 'store', 'product', 'user', 'driver', 'campus', 'settings', 'support', 'announcement', 'category']

export default function ActivityLogs() {
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [action, setAction] = useState('')
  const q = useDebounced(search)
  const { data, meta, loading } = useApi('/admin/activity-logs', { page, search: q, action })

  return (
    <>
      <PageHeader title="Activity logs" subtitle="Audit trail of important actions across the platform." />
      <div className="card overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-line p-4 md:flex-row">
          <SearchInput value={search} onChange={(v) => { setSearch(v); setPage(1) }} placeholder="Search description" />
          <select className="input md:w-48" value={action} onChange={(e) => { setAction(e.target.value); setPage(1) }}>
            <option value="">All actions</option>{ACTIONS.map((a) => <option key={a} value={a}>{a}</option>)}
          </select>
        </div>
        <DataTable loading={loading} rows={data} columns={[
          { key: 'created_at', label: 'When', render: (l) => <span className="whitespace-nowrap text-xs">{dateTime(l.created_at)}</span> },
          { key: 'action', label: 'Action', render: (l) => <Badge tone="blue">{l.action}</Badge> },
          { key: 'description', label: 'Description' },
          { key: 'user', label: 'By', render: (l) => l.user?.name || <span className="text-muted">System</span> },
          { key: 'ip_address', label: 'IP', render: (l) => <span className="text-xs text-muted">{l.ip_address}</span> },
        ]} />
        <Pagination meta={meta} onPage={setPage} />
      </div>
    </>
  )
}
