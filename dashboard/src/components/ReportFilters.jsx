import { Tabs } from './ui'

/** Period tabs + optional custom date range, shared by store and admin reports. */
export default function ReportFilters({ value, onChange, children }) {
  return (
    <div className="mb-6 flex flex-col gap-3 lg:flex-row lg:items-center">
      <Tabs
        value={value.period}
        onChange={(period) => onChange({ ...value, period, from: '', to: '' })}
        tabs={[{ value: 'daily', label: 'Daily' }, { value: 'weekly', label: 'Weekly' }, { value: 'monthly', label: 'Monthly' }]}
      />
      <div className="flex items-center gap-2">
        <input type="date" className="input w-40" value={value.from} onChange={(e) => onChange({ ...value, from: e.target.value })} aria-label="From" />
        <span className="text-muted">to</span>
        <input type="date" className="input w-40" value={value.to} onChange={(e) => onChange({ ...value, to: e.target.value })} aria-label="To" />
      </div>
      <div className="flex-1" />
      {children}
    </div>
  )
}
