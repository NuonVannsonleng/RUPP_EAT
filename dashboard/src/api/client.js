import axios from 'axios'

/**
 * Axios instance for the RUPP Eat Laravel API.
 * In development Vite proxies /api to http://127.0.0.1:8000 (see vite.config.js).
 * For production builds set VITE_API_URL (e.g. https://api.rupp-eat.edu.kh/api).
 */
const TOKEN_KEY = 'rupp_eat_dashboard_token'

export const tokenStore = {
  get: () => {
    try { return localStorage.getItem(TOKEN_KEY) } catch { return null }
  },
  set: (t) => {
    try { localStorage.setItem(TOKEN_KEY, t) } catch { /* storage unavailable */ }
  },
  clear: () => {
    try { localStorage.removeItem(TOKEN_KEY) } catch { /* storage unavailable */ }
  },
}

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api',
  headers: { Accept: 'application/json' },
  timeout: 20000,
})

api.interceptors.request.use((config) => {
  const token = tokenStore.get()
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

let onUnauthorized = () => {}
export const setUnauthorizedHandler = (fn) => { onUnauthorized = fn }

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) onUnauthorized()
    return Promise.reject(normalizeError(error))
  },
)

/** Every API error becomes { message, status, errors }. */
export function normalizeError(error) {
  if (!error.response) {
    return { message: 'Cannot reach the RUPP Eat server. Is the Laravel backend running on port 8000?', status: 0, errors: {} }
  }
  const body = error.response.data || {}
  return {
    message: body.message || `Request failed (${error.response.status})`,
    status: error.response.status,
    errors: body.errors || {},
  }
}

/** Unwraps { success, data, meta, message } */
export const get = (url, params) => api.get(url, { params: clean(params) }).then((r) => r.data)
export const post = (url, data, config) => api.post(url, data, config).then((r) => r.data)
export const put = (url, data) => api.put(url, data).then((r) => r.data)
export const patch = (url, data) => api.patch(url, data).then((r) => r.data)
export const del = (url) => api.delete(url).then((r) => r.data)

/** Multipart upload; Laravel needs POST + _method for PUT with files. */
export function postForm(url, fields, method = 'POST') {
  const fd = new FormData()
  Object.entries(fields).forEach(([k, v]) => {
    if (v === undefined) return
    if (typeof v === 'boolean') fd.append(k, v ? '1' : '0')
    else if (v === null) fd.append(k, '')
    else fd.append(k, v)
  })
  if (method !== 'POST') fd.append('_method', method)
  return api.post(url, fd).then((r) => r.data)
}

/** Downloads a file (CSV export) with the auth header. */
export async function download(url, params, filename) {
  const res = await api.get(url, { params: clean(params), responseType: 'blob' })
  const href = URL.createObjectURL(res.data)
  const a = document.createElement('a')
  a.href = href
  a.download = filename
  a.click()
  URL.revokeObjectURL(href)
}

function clean(params) {
  if (!params) return params
  return Object.fromEntries(Object.entries(params).filter(([, v]) => v !== '' && v !== null && v !== undefined))
}
