import { Navigate, Route, Routes } from 'react-router-dom'
import { useAuth } from './context/AuthContext'
import { PageLoader } from './components/ui'
import AdminLayout from './layouts/AdminLayout'
import StoreLayout from './layouts/StoreLayout'
import Login from './pages/Login'
import ApplyStore from './pages/ApplyStore'
import AdminDashboard from './pages/admin/AdminDashboard'
import Users from './pages/admin/Users'
import Drivers from './pages/admin/Drivers'
import Stores from './pages/admin/Stores'
import Applications from './pages/admin/Applications'
import AdminOrders from './pages/admin/AdminOrders'
import Campus from './pages/admin/Campus'
import Categories from './pages/admin/Categories'
import Announcements from './pages/admin/Announcements'
import Reports from './pages/admin/Reports'
import SettingsPage from './pages/admin/Settings'
import ActivityLogs from './pages/admin/ActivityLogs'
import Support from './pages/admin/Support'
import StoreDashboard from './pages/store/StoreDashboard'
import StoreOrders from './pages/store/StoreOrders'
import Products from './pages/store/Products'
import StoreProfile from './pages/store/StoreProfile'
import StoreReports from './pages/store/StoreReports'

function RequireRole({ role, children }) {
  const { user, ready } = useAuth()
  if (!ready) return <PageLoader />
  if (!user) return <Navigate to="/login" replace />
  if (user.role !== role) return <Navigate to="/" replace />
  return children
}

function Home() {
  const { user, ready } = useAuth()
  if (!ready) return <PageLoader />
  if (!user) return <Navigate to="/login" replace />
  return <Navigate to={user.role === 'admin' ? '/admin' : '/store'} replace />
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="/login" element={<Login />} />
      <Route path="/apply" element={<ApplyStore />} />

      <Route path="/admin" element={<RequireRole role="admin"><AdminLayout /></RequireRole>}>
        <Route index element={<AdminDashboard />} />
        <Route path="reports" element={<Reports />} />
        <Route path="orders" element={<AdminOrders />} />
        <Route path="support" element={<Support />} />
        <Route path="users" element={<Users />} />
        <Route path="drivers" element={<Drivers />} />
        <Route path="stores" element={<Stores />} />
        <Route path="applications" element={<Applications />} />
        <Route path="campus" element={<Campus />} />
        <Route path="categories" element={<Categories />} />
        <Route path="announcements" element={<Announcements />} />
        <Route path="settings" element={<SettingsPage />} />
        <Route path="activity" element={<ActivityLogs />} />
      </Route>

      <Route path="/store" element={<RequireRole role="store_owner"><StoreLayout /></RequireRole>}>
        <Route index element={<StoreDashboard />} />
        <Route path="orders" element={<StoreOrders />} />
        <Route path="products" element={<Products />} />
        <Route path="reports" element={<StoreReports />} />
        <Route path="profile" element={<StoreProfile />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
