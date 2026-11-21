import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { get, post, setUnauthorizedHandler, tokenStore } from '../api/client'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [ready, setReady] = useState(false)
  const [storeId, setStoreIdState] = useState(() => {
    try { return localStorage.getItem('rupp_eat_store') } catch { return null }
  })

  const logoutLocal = useCallback(() => {
    tokenStore.clear()
    setUser(null)
  }, [])

  useEffect(() => {
    setUnauthorizedHandler(logoutLocal)
    if (!tokenStore.get()) {
      setReady(true)
      return
    }
    get('/me')
      .then((res) => setUser(res.data))
      .catch(() => tokenStore.clear())
      .finally(() => setReady(true))
  }, [logoutLocal])

  const login = useCallback(async (login, password) => {
    const res = await post('/login', { login, password, device_name: 'dashboard', app: 'dashboard' })
    tokenStore.set(res.data.token)
    setUser(res.data.user)
    return res.data.user
  }, [])

  const logout = useCallback(async () => {
    try { await post('/logout') } catch { /* already invalid */ }
    logoutLocal()
  }, [logoutLocal])

  const refresh = useCallback(async () => {
    const res = await get('/me')
    setUser(res.data)
  }, [])

  // Store owners may manage more than one store; remember which one is selected.
  const stores = useMemo(() => user?.stores || [], [user])
  const activeStoreId = stores.find((s) => s.id === storeId)?.id || stores[0]?.id || null
  const setStoreId = useCallback((id) => {
    try { localStorage.setItem('rupp_eat_store', id) } catch { /* ignore */ }
    setStoreIdState(id)
  }, [])

  const value = useMemo(
    () => ({ user, ready, login, logout, refresh, stores, storeId: activeStoreId, setStoreId }),
    [user, ready, login, logout, refresh, stores, activeStoreId, setStoreId],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export const useAuth = () => useContext(AuthContext)
