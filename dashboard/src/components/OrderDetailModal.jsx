import { useEffect, useState } from 'react'
import { MapPin, Phone, Store, User, Bike } from 'lucide-react'
import { get } from '../api/client'
import { Modal, PageLoader, StatusBadge } from './ui'
import { dateTime, money, time } from '../utils/format'

/** Full order view: items, campus destination, people, status timeline. */
export default function OrderDetailModal({ orderId, onClose, actions }) {
  const [order, setOrder] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!orderId) return
    setOrder(null)
    get(`/orders/${orderId}`).then((r) => setOrder(r.data)).catch((e) => setError(e.message))
  }, [orderId])

  const loc = order?.delivery_location

  return (
    <Modal open={!!orderId} onClose={onClose} size="lg" title={order ? `Order ${order.order_number}` : 'Order'}
      footer={order && actions ? actions(order, setOrder) : null}>
      {error && <p className="text-sm text-red-600">{error}</p>}
      {!order && !error && <PageLoader />}
      {order && (
        <div className="grid gap-5 md:grid-cols-5">
          <div className="space-y-4 md:col-span-3">
            <div className="flex flex-wrap items-center gap-2">
              <StatusBadge status={order.status} label={order.status_label} />
              <StatusBadge status={order.fulfillment_method === 'delivery' ? 'assigned' : 'ready'} label={order.fulfillment_method === 'delivery' ? 'Classroom delivery' : 'Self-pickup'} />
              <StatusBadge status={order.payment_status} label={`${order.payment_method_label} · ${order.payment_status}`} />
            </div>

            <div className="rounded-xl border border-line">
              {order.items?.map((i) => (
                <div key={i.id} className="flex items-start gap-3 border-b border-line px-4 py-2.5 last:border-0">
                  <span className="rounded-md bg-accent-50 px-1.5 text-sm font-bold text-accent-600">{i.quantity}×</span>
                  <div className="flex-1">
                    <p className="text-sm font-medium">{i.product_name}</p>
                    {i.note && <p className="text-xs text-muted">Note: {i.note}</p>}
                  </div>
                  <span className="text-sm font-semibold">{money(i.line_total)}</span>
                </div>
              ))}
              <div className="space-y-1 bg-canvas/60 px-4 py-3 text-sm">
                <div className="flex justify-between"><span className="text-muted">Subtotal</span><span>{money(order.subtotal)}</span></div>
                <div className="flex justify-between"><span className="text-muted">Delivery fee</span><span>{money(order.delivery_fee)}</span></div>
                <div className="flex justify-between text-base font-extrabold"><span>Total</span><span className="text-accent-600">{money(order.total)}</span></div>
              </div>
            </div>

            {order.customer_note && <div className="rounded-xl bg-accent-50 px-4 py-3 text-sm"><b>Customer note:</b> {order.customer_note}</div>}
            {order.cancel_reason && <div className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700"><b>Reason:</b> {order.cancel_reason}</div>}
          </div>

          <div className="space-y-4 md:col-span-2">
            {order.fulfillment_method === 'delivery' && loc && (
              <div className="rounded-xl border border-line p-4">
                <p className="mb-2 flex items-center gap-2 text-sm font-bold"><MapPin className="h-4 w-4 text-brand-600" /> Deliver to</p>
                <p className="text-lg font-extrabold text-brand-600">{loc.room}</p>
                <p className="text-sm">{loc.building} · {loc.floor_label || `Floor ${loc.floor}`}</p>
                <p className="text-xs text-muted">{loc.faculty}</p>
                {order.delivery_instructions && <p className="mt-2 rounded-lg bg-canvas px-2.5 py-1.5 text-xs">“{order.delivery_instructions}”</p>}
              </div>
            )}
            <div className="space-y-2.5 rounded-xl border border-line p-4 text-sm">
              {order.customer && <Person icon={User} title={order.customer.name} sub={[order.customer.university_id, order.customer.phone].filter(Boolean).join(' · ')} />}
              {order.store && <Person icon={Store} title={order.store.name} sub={order.store.building} />}
              {order.driver && <Person icon={Bike} title={order.driver.name} sub={order.driver.phone} />}
              {order.pickup_code && <p className="text-xs text-muted">Pickup code: <b className="text-ink">{order.pickup_code}</b></p>}
              <p className="text-xs text-muted">Placed {dateTime(order.created_at)}</p>
            </div>
            <div className="rounded-xl border border-line p-4">
              <p className="mb-3 text-sm font-bold">Timeline</p>
              <ol className="space-y-2.5">
                {order.timeline?.map((t, idx) => (
                  <li key={idx} className="flex gap-3 text-sm">
                    <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-accent-500" />
                    <div className="flex-1">
                      <p className="font-medium">{t.label}</p>
                      {t.note && <p className="text-xs text-muted">{t.note}</p>}
                    </div>
                    <span className="text-xs text-muted">{time(t.at)}</span>
                  </li>
                ))}
              </ol>
            </div>
          </div>
        </div>
      )}
    </Modal>
  )
}

function Person({ icon: Icon, title, sub }) {
  return (
    <div className="flex items-start gap-2.5">
      <Icon className="mt-0.5 h-4 w-4 text-muted" />
      <div>
        <p className="font-semibold">{title}</p>
        {sub && <p className="flex items-center gap-1 text-xs text-muted"><Phone className="h-3 w-3" />{sub}</p>}
      </div>
    </div>
  )
}
