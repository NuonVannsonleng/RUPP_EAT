import { Activity, BarChart3, Bike, Building2, ClipboardList, FileCheck2, LayoutDashboard, LifeBuoy, Megaphone, Settings, Store, Tags, Users } from 'lucide-react'
import Shell from './Shell'
import { useApi } from '../hooks/useApi'
import { Badge } from '../components/ui'

export default function AdminLayout() {
  // Small counters for the sidebar, refreshed every minute.
  const { data } = useApi('/admin/dashboard', {}, { pollMs: 60000 })

  const nav = [
    { title: 'Overview', items: [
      { to: '/admin', label: 'Dashboard', icon: LayoutDashboard, end: true },
      { to: '/admin/reports', label: 'Reports & analytics', icon: BarChart3 },
    ] },
    { title: 'Operations', items: [
      { to: '/admin/orders', label: 'Orders', icon: ClipboardList, badge: data?.active_orders },
      { to: '/admin/support', label: 'Support & disputes', icon: LifeBuoy, badge: data?.open_support_tickets },
    ] },
    { title: 'People & stores', items: [
      { to: '/admin/users', label: 'Users', icon: Users },
      { to: '/admin/drivers', label: 'Drivers', icon: Bike, badge: data?.pending_driver_verifications },
      { to: '/admin/stores', label: 'Stores', icon: Store },
      { to: '/admin/applications', label: 'Store applications', icon: FileCheck2, badge: data?.pending_store_applications },
    ] },
    { title: 'Platform', items: [
      { to: '/admin/campus', label: 'Campus locations', icon: Building2 },
      { to: '/admin/categories', label: 'Food categories', icon: Tags },
      { to: '/admin/announcements', label: 'Announcements', icon: Megaphone },
      { to: '/admin/settings', label: 'System settings', icon: Settings },
      { to: '/admin/activity', label: 'Activity logs', icon: Activity },
    ] },
  ]

  return (
    <Shell
      variant="admin"
      nav={nav}
      roleLabel="Administrator"
      headerRight={
        <div className="flex items-center gap-2 text-sm">
          {data && <Badge tone="green">{data.online_drivers} drivers online</Badge>}
          {data && <Badge tone="orange">{data.active_deliveries} active deliveries</Badge>}
        </div>
      }
    />
  )
}
