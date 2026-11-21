import { useCallback, useEffect, useRef, useState } from 'react'
import { get } from '../api/client'

/**
 * Loads a GET endpoint and re-loads whenever `params` change.
 * Returns { data, meta, loading, error, reload }.
 * pollMs: refresh silently on an interval (live order boards).
 */
export function useApi(url, params = {}, { pollMs, enabled = true } = {}) {
  const [state, setState] = useState({ data: null, meta: null, loading: true, error: null })
  const key = JSON.stringify(params)
  const latest = useRef(0)

  const load = useCallback(async (silent = false) => {
    if (!enabled || !url) return
    const id = ++latest.current
    if (!silent) setState((s) => ({ ...s, loading: true, error: null }))
    try {
      const res = await get(url, JSON.parse(key))
      if (id === latest.current) setState({ data: res.data, meta: res.meta || null, loading: false, error: null })
    } catch (err) {
      if (id === latest.current) setState((s) => ({ ...s, loading: false, error: silent ? s.error : err.message }))
    }
  }, [url, key, enabled])

  useEffect(() => { load() }, [load])

  useEffect(() => {
    if (!pollMs) return
    const t = setInterval(() => {
      if (document.visibilityState === 'visible') load(true)
    }, pollMs)
    return () => clearInterval(t)
  }, [load, pollMs])

  return { ...state, reload: load }
}

/** Debounced value for search boxes. */
export function useDebounced(value, ms = 350) {
  const [v, setV] = useState(value)
  useEffect(() => {
    const t = setTimeout(() => setV(value), ms)
    return () => clearTimeout(t)
  }, [value, ms])
  return v
}
