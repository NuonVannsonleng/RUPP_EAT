import { useState } from 'react'
import { Link, Navigate, useNavigate } from 'react-router-dom'
import { Eye, EyeOff, Loader2, Store, ShieldCheck } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { firstError } from '../utils/format'

export default function Login() {
  const { user, login } = useAuth()
  const navigate = useNavigate()
  const [form, setForm] = useState({ login: '', password: '' })
  const [show, setShow] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  if (user) return <Navigate to="/" replace />

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    try {
      const u = await login(form.login.trim(), form.password)
      navigate(u.role === 'admin' ? '/admin' : '/store', { replace: true })
    } catch (err) {
      setError(firstError(err))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="grid min-h-full lg:grid-cols-2">
      <div className="relative hidden overflow-hidden bg-brand-700 p-12 text-white lg:flex lg:flex-col lg:justify-between">
        <img src="/brand/rupp-building.webp" alt="" className="absolute inset-x-0 bottom-0 w-full object-cover opacity-70" />
        <div className="absolute inset-0 bg-gradient-to-b from-brand-900/85 via-brand-700/60 to-brand-700/70" />
        <div className="relative flex items-center gap-4">
          <img src="/brand/rupp-logo.png" alt="RUPP seal" className="h-16 w-16 rounded-full bg-white p-1 shadow-lg" />
          <div>
            <p className="font-['Kantumruy_Pro'] text-xl font-bold">សាកលវិទ្យាល័យភូមិន្ទភ្នំពេញ</p>
            <p className="text-sm text-white/70">Royal University of Phnom Penh</p>
          </div>
        </div>
        <div className="relative max-w-md">
          <p className="mb-3 text-2xl font-black tracking-wide">RUPP <span className="text-accent-400">Eat</span></p>
          <h1 className="text-4xl font-extrabold leading-tight">Campus food, managed in one place.</h1>
          <p className="mt-4 text-white/75">Royal University of Phnom Penh stores and administrators manage menus, orders, classroom deliveries and reports here.</p>
          <div className="mt-8 grid gap-3 text-sm">
            <div className="flex items-center gap-3 rounded-xl bg-white/10 p-3"><ShieldCheck className="h-5 w-5 text-accent-400" /> Administrators: platform, users, stores, campus</div>
            <div className="flex items-center gap-3 rounded-xl bg-white/10 p-3"><Store className="h-5 w-5 text-accent-400" /> Store owners: menu, live orders, sales</div>
          </div>
        </div>
        <p className="relative text-xs text-white/50">Students, lecturers, staff and drivers use the RUPP Eat mobile app.</p>
      </div>

      <div className="flex items-center justify-center p-6">
        <form onSubmit={submit} className="w-full max-w-sm">
          <div className="mb-8 lg:hidden">
            <span className="inline-flex items-center gap-2 text-lg font-black"><img src="/brand/rupp-logo.png" alt="" className="h-9 w-9" /><span className="text-brand-600">RUPP</span> <span className="text-accent-400">Eat</span></span>
          </div>
          <h2 className="text-3xl font-extrabold tracking-tight">Welcome back</h2>
          <p className="mt-1 text-sm text-muted">Sign in to the RUPP Eat dashboard.</p>

          {error && <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm font-medium text-red-700">{error}</div>}

          <label className="mt-6 block">
            <span className="label">Email or staff ID</span>
            <input className="input" autoFocus value={form.login} onChange={(e) => setForm({ ...form, login: e.target.value })} placeholder="admin@rupp.edu.kh" required />
          </label>
          <label className="mt-4 block">
            <span className="label">Password</span>
            <div className="relative">
              <input className="input pr-10" type={show ? 'text' : 'password'} value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} required />
              <button type="button" className="absolute right-3 top-1/2 -translate-y-1/2 text-muted" onClick={() => setShow(!show)} aria-label="Show password">
                {show ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          </label>

          <button className="btn mt-6 w-full bg-gradient-to-r from-brand-500 to-brand-600 py-3 text-base text-white shadow-lg shadow-brand-600/25 hover:brightness-105" disabled={loading}>
            {loading && <Loader2 className="h-4 w-4 animate-spin" />} Log in
          </button>

          <p className="mt-8 text-center text-sm text-muted">
            New food store on campus? <Link to="/apply" className="font-semibold text-accent-600 hover:underline">Apply to join RUPP Eat</Link>
          </p>
        </form>
      </div>
    </div>
  )
}
