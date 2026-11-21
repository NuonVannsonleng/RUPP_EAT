import { useState } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import { LogOut, Menu, X } from 'lucide-react'
import { useAuth } from '../context/AuthContext'

export function Logo({ light = false }) {
  return (
    <div className="flex items-center gap-2.5">
      <img src="/brand/rupp-logo.png" alt="RUPP" className="h-10 w-10 rounded-full bg-white p-0.5 shadow" />
      <div className="leading-tight">
        <p className="text-base font-black tracking-wide">
          <span className={light ? 'text-white' : 'text-brand-600'}>RUPP</span> <span className="text-accent-400">Eat</span>
        </p>
        <p className={`text-[11px] font-semibold uppercase tracking-wider ${light ? 'text-white/60' : 'text-muted'}`}>Dashboard</p>
      </div>
    </div>
  )
}

/**
 * Generic sidebar shell. Admin and store layouts pass their own navigation,
 * colours and header content so each role gets its own interface.
 */
export default function Shell({ nav, variant = 'admin', sidebarTop, headerRight, roleLabel }) {
  const { user, logout } = useAuth()
  const [open, setOpen] = useState(false)
  const dark = variant === 'admin'

  const sidebar = (
    <aside className={`flex h-full w-64 flex-col ${dark ? 'bg-brand-800 text-white' : 'border-r border-line bg-white'}`}>
      <div className="flex h-16 items-center justify-between px-5">
        <Logo light={dark} />
        <button className="lg:hidden" onClick={() => setOpen(false)} aria-label="Close menu"><X className="h-5 w-5" /></button>
      </div>
      {sidebarTop && <div className="px-4 pb-3">{sidebarTop}</div>}
      <nav className="flex-1 space-y-5 overflow-y-auto px-3 pb-4">
        {nav.map((group) => (
          <div key={group.title}>
            <p className={`px-3 pb-1.5 text-[11px] font-bold uppercase tracking-wider ${dark ? 'text-white/45' : 'text-muted'}`}>{group.title}</p>
            {group.items.map(({ to, label, icon: Icon, end, badge }) => (
              <NavLink
                key={to}
                to={to}
                end={end}
                onClick={() => setOpen(false)}
                className={({ isActive }) =>
                  `mb-0.5 flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold transition ${
                    dark
                      ? isActive ? 'bg-white/12 text-white shadow-inner' : 'text-white/70 hover:bg-white/8 hover:text-white'
                      : isActive ? 'bg-accent-50 text-accent-600' : 'text-muted hover:bg-canvas hover:text-ink'
                  }`
                }
              >
                <Icon className="h-[18px] w-[18px]" />
                <span className="flex-1">{label}</span>
                {badge ? <span className="rounded-full bg-accent-500 px-1.5 text-[11px] font-bold text-white">{badge}</span> : null}
              </NavLink>
            ))}
          </div>
        ))}
      </nav>
      <div className={`border-t p-4 ${dark ? 'border-white/10' : 'border-line'}`}>
        <div className="flex items-center gap-3">
          <div className={`flex h-9 w-9 items-center justify-center rounded-full text-sm font-bold ${dark ? 'bg-accent-400 text-ink' : 'bg-brand-600 text-white'}`}>
            {user?.name?.split(' ').map((p) => p[0]).slice(0, 2).join('')}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold">{user?.name}</p>
            <p className={`truncate text-xs ${dark ? 'text-white/55' : 'text-muted'}`}>{roleLabel}</p>
          </div>
          <button onClick={logout} title="Log out" className={`rounded-lg p-2 ${dark ? 'hover:bg-white/10' : 'hover:bg-canvas'}`}><LogOut className="h-4 w-4" /></button>
        </div>
      </div>
    </aside>
  )

  return (
    <div className="flex h-full">
      <div className="hidden lg:block">{sidebar}</div>
      {open && (
        <div className="fixed inset-0 z-40 flex lg:hidden">
          <div className="h-full">{sidebar}</div>
          <div className="flex-1 bg-ink/40" onClick={() => setOpen(false)} />
        </div>
      )}
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-line bg-white/90 px-4 backdrop-blur sm:px-6">
          <button className="btn-ghost p-2 lg:hidden" onClick={() => setOpen(true)} aria-label="Open menu"><Menu className="h-5 w-5" /></button>
          <div className="flex-1" />
          {headerRight}
        </header>
        <main className="flex-1 overflow-y-auto px-4 py-6 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl"><Outlet /></div>
        </main>
      </div>
    </div>
  )
}
