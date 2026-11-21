import { useEffect, useState } from 'react'
import { BarChart3, ClipboardList, LayoutDashboard, Store, UtensilsCrossed } from 'lucide-react'
import Shell from './Shell'
import { useAuth } from '../context/AuthContext'
import { useApi } from '../hooks/useApi'
import { postForm } from '../api/client'
import { Toggle, useToast } from '../components/ui'

export default function StoreLayout() {
  const { stores, storeId, setStoreId } = useAuth()
  const { data: dash } = useApi('/store/dashboard', { store_id: storeId }, { pollMs: 15000, enabled: !!storeId })
  const { data: myStores, reload } = useApi('/store/stores')
  const toast = useToast()
  const current = myStores?.find((s) => s.id === storeId)
  const [isOpen, setIsOpen] = useState(false)

  useEffect(() => { if (current) setIsOpen(current.is_open) }, [current])

  // Play a short beep when a new order arrives.
  const pending = dash?.pending
  const [lastPending, setLastPending] = useState(null)
  useEffect(() => {
    if (pending === undefined) return // not loaded yet
    if (lastPending !== null && pending > lastPending) {
      toast(`New order received! ${pending} waiting for confirmation.`)
      try {
        const ctx = new AudioContext()
        const o = ctx.createOscillator()
        o.frequency.value = 880
        o.connect(ctx.destination)
        o.start()
        o.stop(ctx.currentTime + 0.18)
      } catch { /* audio not allowed */ }
    }
    setLastPending(pending)
  }, [pending]) // eslint-disable-line react-hooks/exhaustive-deps

  const toggleOpen = async (value) => {
    setIsOpen(value)
    try {
      await postForm(`/stores/${storeId}`, { is_open: value }, 'PUT')
      toast(value ? 'Store is now open for orders' : 'Store is now closed')
      reload()
    } catch (e) {
      setIsOpen(!value)
      toast(e.message, 'error')
    }
  }

  const nav = [
    { title: 'My store', items: [
      { to: '/store', label: 'Dashboard', icon: LayoutDashboard, end: true },
      { to: '/store/orders', label: 'Orders', icon: ClipboardList, badge: pending || null },
      { to: '/store/products', label: 'Menu & products', icon: UtensilsCrossed },
      { to: '/store/reports', label: 'Sales & reports', icon: BarChart3 },
      { to: '/store/profile', label: 'Store profile', icon: Store },
    ] },
  ]

  const switcher = stores.length > 1 && (
    <select className="input" value={storeId || ''} onChange={(e) => setStoreId(e.target.value)}>
      {stores.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
    </select>
  )

  return (
    <Shell
      variant="store"
      nav={nav}
      roleLabel={current?.name || 'Store owner'}
      sidebarTop={switcher}
      headerRight={current && (
        <div className="flex items-center gap-3">
          <div className="hidden text-right sm:block">
            <p className="text-sm font-bold">{current.name}</p>
            <p className={`text-xs font-semibold ${current.is_open_now ? 'text-emerald-600' : 'text-red-600'}`}>
              {current.is_open_now ? 'Accepting orders' : isOpen ? `Outside hours (${current.opening_time}–${current.closing_time})` : 'Closed'}
            </p>
          </div>
          <Toggle checked={isOpen} onChange={toggleOpen} label="Store open" disabled={current.status !== 'active'} />
        </div>
      )}
    />
  )
}
