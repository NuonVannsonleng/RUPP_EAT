import { Area, AreaChart, Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { money, statusLabel } from '../utils/format'

const BLUE = '#1f4d3a'
const ORANGE = '#d9a82b'
const PALETTE = ['#1f4d3a', '#d9a82b', '#4caf50', '#7c4dbb', '#8bc34a', '#c62828', '#1565c0', '#8a948e']

function ChartTooltip({ active, payload, label, currency = true }) {
  if (!active || !payload?.length) return null
  return (
    <div className="rounded-xl border border-line bg-white px-3 py-2 text-xs shadow-lg">
      <p className="mb-1 font-semibold">{label}</p>
      {payload.map((p) => (
        <p key={p.dataKey} className="flex items-center gap-2">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color }} />
          <span className="text-muted">{p.name}:</span>
          <span className="font-semibold">{currency && p.dataKey === 'revenue' ? money(p.value) : p.value}</span>
        </p>
      ))}
    </div>
  )
}

/** Revenue area + order count bars over time. */
export function RevenueChart({ data, height = 280 }) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 8, right: 8, left: -12, bottom: 0 }}>
        <defs>
          <linearGradient id="rev" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={BLUE} stopOpacity={0.25} />
            <stop offset="100%" stopColor={BLUE} stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid stroke="#eef0f5" vertical={false} />
        <XAxis dataKey="label" tick={{ fontSize: 11, fill: '#6b7385' }} tickLine={false} axisLine={false} minTickGap={16} />
        <YAxis yAxisId="r" tick={{ fontSize: 11, fill: '#6b7385' }} tickLine={false} axisLine={false} tickFormatter={(v) => `$${v}`} />
        <YAxis yAxisId="o" orientation="right" hide />
        <Tooltip content={<ChartTooltip />} />
        <Area yAxisId="r" type="monotone" dataKey="revenue" name="Revenue" stroke={BLUE} strokeWidth={2.5} fill="url(#rev)" />
        <Area yAxisId="o" type="monotone" dataKey="orders" name="Orders" stroke={ORANGE} strokeWidth={2} fill="transparent" strokeDasharray="4 3" />
      </AreaChart>
    </ResponsiveContainer>
  )
}

/** Horizontal bars (best sellers, revenue by store). */
export function HBarChart({ data, dataKey, nameKey = 'name', height, currency = false }) {
  const h = height || Math.max(160, data.length * 38)
  return (
    <ResponsiveContainer width="100%" height={h}>
      <BarChart data={data} layout="vertical" margin={{ top: 0, right: 16, left: 8, bottom: 0 }}>
        <CartesianGrid stroke="#eef0f5" horizontal={false} />
        <XAxis type="number" tick={{ fontSize: 11, fill: '#6b7385' }} tickLine={false} axisLine={false} tickFormatter={(v) => (currency ? `$${v}` : v)} />
        <YAxis type="category" dataKey={nameKey} width={150} tick={{ fontSize: 12, fill: '#1a2233' }} tickLine={false} axisLine={false} />
        <Tooltip cursor={{ fill: '#f6f7fb' }} formatter={(v) => (currency ? money(v) : v)} />
        <Bar dataKey={dataKey} radius={[0, 6, 6, 0]} fill={BLUE} barSize={18} />
      </BarChart>
    </ResponsiveContainer>
  )
}

/** Donut for status / fulfillment splits. data: { key: count } */
export function DonutChart({ data, height = 220, labelFn = statusLabel }) {
  const rows = Object.entries(data || {}).map(([k, v]) => ({ name: labelFn(k), value: v }))
  const total = rows.reduce((s, r) => s + r.value, 0)
  if (!total) return <p className="py-10 text-center text-sm text-muted">No data for this period.</p>
  return (
    <div className="flex flex-col items-center gap-4 @container">
      <div className="w-full max-w-[240px]" style={{ height: Math.min(height, 200) }}>
        <ResponsiveContainer>
          <PieChart>
            <Pie data={rows} dataKey="value" nameKey="name" innerRadius="58%" outerRadius="88%" paddingAngle={2} stroke="none">
              {rows.map((_, i) => <Cell key={i} fill={PALETTE[i % PALETTE.length]} />)}
            </Pie>
            <Tooltip />
          </PieChart>
        </ResponsiveContainer>
      </div>
      <ul className="grid w-full gap-x-6 gap-y-1.5 text-sm @md:grid-cols-2">
        {rows.map((r, i) => (
          <li key={r.name} className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-sm" style={{ background: PALETTE[i % PALETTE.length] }} />
            <span className="flex-1 truncate">{r.name}</span>
            <span className="font-semibold">{r.value}</span>
            <span className="w-10 text-right text-xs text-muted">{Math.round((r.value / total) * 100)}%</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
