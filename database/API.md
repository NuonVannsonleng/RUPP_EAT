# RUPP Eat — REST API reference

Base URL: `http://<host>:8000/api` · Auth: `Authorization: Bearer <sanctum token>` · `Accept: application/json`

Every response uses one envelope:

```json
{ "success": true, "message": "Order placed!", "data": { }, "meta": { "current_page": 1, "last_page": 4, "per_page": 15, "total": 52 } }
```

Errors: `{ "success": false, "message": "...", "data": null, "errors": { "field": ["..."] } }` with 401 / 403 / 404 / 409 / 422 / 429.
Lists accept `page` and `per_page` (max 100).

## Authentication (public, rate-limited 10/min)

| Method | Path | Notes |
|---|---|---|
| POST | `/register` | Customer sign-up: `name, email, university_id, user_type (student\|lecturer\|staff), phone, password, password_confirmation` |
| POST | `/login` | `login` (email **or** student/staff ID), `password`, optional `app` = `mobile` \| `dashboard` (enforces the right client per role) |
| POST | `/forgot-password` | Emails a 6-digit code (dev: see `storage/logs/laravel.log`) |
| POST | `/reset-password` | `email, code, password, password_confirmation` |
| POST | `/logout` | Revokes current token |
| GET | `/me` | Current user (+ driver profile / managed stores) |
| POST/PUT | `/me` | Update profile (multipart for `avatar`) |
| PUT | `/me/password` | `current_password, password, password_confirmation` (signs out other devices) |
| PUT | `/me/fcm-token` | Save Firebase push token |

## Catalog (signed in)

| Method | Path | Notes |
|---|---|---|
| GET | `/home` | Customer home feed: categories, featured stores, popular & recent products, active orders, announcements |
| GET | `/categories` | Food categories |
| GET | `/stores` | `search, category, featured, favorites, open_now, sort=rating\|popular\|name` |
| GET | `/stores/{id}` | Store + categories + pickup location |
| GET | `/stores/{id}/products` | Menu. `manage=1` includes unavailable items (owners) |
| GET | `/products` | `search, category, store_id, sort=popular\|price_asc\|price_desc\|newest\|rating` |
| GET | `/stores/{id}/reviews`, `/products/{id}/reviews` | Reviews |
| GET | `/campus/locations` | Faculty → building → floor → classroom tree (public) |
| GET | `/settings/public` | Delivery fee, free-delivery threshold, KHQR flag, support contacts (public) |

## Customer

| Method | Path | Notes |
|---|---|---|
| GET | `/cart` | `fulfillment_method` changes the fee preview |
| POST | `/cart/items` | `product_id, quantity, note?, replace?` — **409** if cart holds another store's items |
| PATCH / DELETE | `/cart/items/{id}` | Change quantity (0 removes) / remove |
| DELETE | `/cart` | Clear |
| POST | `/orders` | `fulfillment_method, payment_method, classroom_id (delivery), delivery_instructions?, customer_note?` + header **`Idempotency-Key`**. Items & prices come from the server cart |
| GET | `/orders` | Role-scoped list. `status=active\|completed\|cancelled\|<csv>`, `store_id, customer_id, driver_id, fulfillment_method, date_from, date_to, search` |
| GET | `/orders/{id}` | Policy: customer, assigned driver, store staff, admin |
| PATCH | `/orders/{id}/status` | Customer: `cancelled` while pending. Store/admin: see state machine |
| POST | `/orders/{id}/reorder` | Copies available items back into the cart |
| POST | `/orders/{id}/reviews` | `rating, comment?, products[{product_id, rating, comment?}]` — completed orders only, once |
| GET / POST | `/favorites`, `/favorites/{storeId}` | List / toggle |
| GET / POST | `/notifications`, `/notifications/{id}/read`, `/notifications/read-all`, `/notifications/unread-count` | Inbox |
| GET / POST | `/support-tickets` | Contact support (optionally about an order) |

## Driver (`role:driver`)

| Method | Path | Notes |
|---|---|---|
| GET | `/driver/dashboard` | Online state, verification, today/week stats & earnings, active deliveries |
| POST | `/driver/availability` | `is_online` — only verified + active drivers |
| GET | `/driver/deliveries` | `type=available\|active\|completed\|cancelled\|history` |
| GET | `/driver/deliveries/{id}` | Only own deliveries or open requests |
| POST | `/driver/deliveries/{id}/accept` | Row-locked; second driver gets **409** |
| POST | `/driver/deliveries/{id}/reject` | Hide this request for me |
| POST | `/driver/deliveries/{id}/release` | Give back before pickup |
| PATCH | `/driver/deliveries/{id}/status` | `picked_up` (store must have marked ready) → `arriving` (notifies customer) → `delivered` (cash marked paid) |

Customer phone/name are only returned to the **assigned** driver.

## Store owner / staff (`role:store_owner`; admins may use the shared ones)

| Method | Path | Notes |
|---|---|---|
| PUT / POST | `/stores/{id}` | Update own store (multipart `logo`, `cover`; POST + `_method=PUT`) |
| POST | `/products` | Add product (`store_id` optional when you manage one store) |
| PUT / POST | `/products/{id}` | Edit (multipart `image`) |
| DELETE | `/products/{id}` | Soft delete |
| POST | `/orders/{id}/request-driver` | Release a delivery order to drivers |
| GET | `/store/stores` | Stores I manage |
| GET | `/store/dashboard?store_id=` | Today's orders, pending, preparing, sales, 7-day chart, popular products |
| GET | `/store/reports` | `period=daily\|weekly\|monthly, from, to` — revenue series, best sellers, status & fulfillment split |

## Administrator (`role:admin`)

| Method | Path |
|---|---|
| GET | `/admin/dashboard`, `/admin/reports`, `/admin/reports/export?type=orders\|stores\|products\|drivers` (CSV) |
| GET/POST/PUT/PATCH | `/admin/users`, `/admin/users/{id}`, `/admin/users/{id}/status`, `/admin/roles` |
| PATCH / GET | `/admin/drivers/{id}/verification`, `/admin/drivers/{id}/active`, `/admin/drivers/{id}/deliveries` |
| POST | `/stores` (register a store) |
| GET/PATCH/DELETE | `/admin/stores`, `/admin/stores/{id}/status`, `/admin/stores/{id}` |
| GET/POST | `/admin/store-applications`, `/{id}/approve`, `/{id}/reject` (+ public `POST /store-applications`) |
| GET | `/admin/orders` |
| CRUD | `/admin/campus` (tree), `/admin/faculties`, `/admin/buildings`, `/admin/floors`, `/admin/classrooms` |
| CRUD | `/admin/categories`, `/admin/announcements` |
| GET/PUT | `/admin/settings` (`{ settings: { delivery_fee: 0.5, ... } }`) |
| GET | `/admin/activity-logs` |
| GET/POST | `/admin/support-tickets`, `/admin/support-tickets/{id}/resolve` |
