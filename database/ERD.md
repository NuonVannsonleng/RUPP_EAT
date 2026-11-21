# RUPP Eat — Database design (PostgreSQL)

All primary keys are **UUIDs** (`HasUuids`). Money is `numeric(10,2)` in USD. Timestamps use the
`Asia/Phnom_Penh` timezone. Soft deletes on `users`, `stores`, `products`, `faculties`, `buildings`, `classrooms`
so order history never loses its references.

Migrations: [`backend/database/migrations`](../backend/database/migrations) · Seeders: [`backend/database/seeders`](../backend/database/seeders)

## Entity–relationship diagram

```mermaid
erDiagram
    roles ||--o{ users : "has"
    users ||--o| driver_profiles : "driver details"
    users ||--o{ stores : "owns"
    stores ||--o{ store_staff : ""
    users ||--o{ store_staff : "works at"
    users ||--o{ store_applications : "applies"

    faculties ||--o{ buildings : ""
    buildings ||--o{ floors : ""
    floors ||--o{ classrooms : ""
    buildings ||--o{ stores : "located in"

    product_categories ||--o{ products : ""
    stores ||--o{ products : "sells"

    users ||--o| carts : ""
    carts ||--o{ cart_items : ""
    products ||--o{ cart_items : ""

    users ||--o{ orders : "places (customer)"
    users ||--o{ orders : "delivers (driver)"
    stores ||--o{ orders : "receives"
    classrooms ||--o{ orders : "delivered to"
    orders ||--|{ order_items : ""
    products ||--o{ order_items : ""
    orders ||--o{ order_status_logs : "timeline"
    orders ||--o| deliveries : ""
    deliveries ||--o{ delivery_status_logs : ""
    deliveries ||--o{ delivery_declines : ""
    orders ||--o{ payments : ""
    orders ||--o{ reviews : ""
    stores ||--o{ reviews : ""
    products ||--o{ reviews : ""

    users ||--o{ favorites : ""
    stores ||--o{ favorites : ""
    users ||--o{ notifications : ""
    users ||--o{ support_tickets : ""
    users ||--o{ activity_logs : ""
    stores ||--o{ announcements : "promotes"

    users {
        uuid id PK
        uuid role_id FK
        string email UK
        string university_id UK "student / staff ID"
        string user_type "student|lecturer|staff"
        string status "active|suspended"
        string fcm_token
    }
    driver_profiles {
        uuid id PK
        uuid user_id FK,UK
        string verification_status "pending|verified|rejected"
        bool is_active
        bool is_online
    }
    stores {
        uuid id PK
        uuid owner_id FK
        uuid building_id FK
        string slug UK
        time opening_time
        time closing_time
        string status "active|suspended"
        bool is_open
        decimal rating_avg
    }
    products {
        uuid id PK
        uuid store_id FK
        uuid category_id FK
        decimal price "CHECK >= 0"
        int stock_quantity "NULL = untracked, CHECK >= 0"
        bool is_available
        int sold_count
    }
    orders {
        uuid id PK
        string order_number UK
        uuid customer_id FK
        uuid store_id FK
        uuid driver_id FK "nullable"
        string fulfillment_method "delivery|pickup"
        string payment_method "cash_on_delivery|cash_on_pickup|khqr"
        string payment_status
        string status
        decimal subtotal
        decimal delivery_fee
        decimal total
        uuid classroom_id FK
        jsonb delivery_location "snapshot"
        string pickup_code
        string idempotency_key "UK with customer_id"
    }
    deliveries {
        uuid id PK
        uuid order_id FK,UK
        uuid driver_id FK
        string status "pending|searching|assigned|picked_up|arriving|delivered|cancelled"
    }
    payments {
        uuid id PK
        uuid order_id FK
        string method
        decimal amount
        string status "pending|paid|cancelled|refunded"
        string provider_reference "UK with provider"
    }
```

## Key constraints & indexes

| Table | Constraint / index | Why |
|---|---|---|
| `orders` | `UNIQUE(customer_id, idempotency_key)` | Duplicate submissions (double tap, retry) return the same order |
| `orders` | `CHECK fulfillment_method IN ('delivery','pickup')`, `CHECK amounts >= 0` | Data integrity |
| `orders` | indexes on `(store_id,status)`, `(customer_id,created_at)`, `(driver_id,status)`, `status`, `created_at` | Order boards, history, reports |
| `products` | `CHECK price >= 0`, `CHECK stock_quantity >= 0` | Stock can never go negative even under race conditions |
| `deliveries` | `UNIQUE(order_id)`; row lock on accept | Only one driver can win a delivery |
| `delivery_declines` | `UNIQUE(delivery_id, driver_id)` | A rejected request stays hidden for that driver |
| `reviews` | partial unique indexes (store review / product review per order), `CHECK rating 1–5` | One review per order |
| `favorites`, `store_staff`, `cart_items` | composite unique keys | No duplicates |
| `floors` / `classrooms` | `UNIQUE(building_id, number)` / `UNIQUE(floor_id, name)` | Clean campus hierarchy |
| `payments` | `UNIQUE(provider, provider_reference)` | A KHQR transaction can only pay one order |

## Order state machine

```mermaid
stateDiagram-v2
    [*] --> pending : customer places order
    pending --> accepted : store accepts
    pending --> rejected : store rejects
    pending --> cancelled : customer cancels
    accepted --> preparing
    preparing --> ready
    accepted --> cancelled : store / admin
    preparing --> cancelled : store / admin
    ready --> picked_up : pickup — store verifies 4-digit code
    ready --> driver_assigned : delivery — driver accepted
    driver_assigned --> on_the_way : driver confirms pickup
    on_the_way --> delivered : driver confirms delivery
    delivered --> [*]
    picked_up --> [*]
```

Side effects handled in one DB transaction by `OrderWorkflowService`: timestamps, stock return on
cancel/reject, payment status (cash is marked **paid only when handed over**), `sold_count`,
delivery record, status log, then notifications + broadcast event after commit.
