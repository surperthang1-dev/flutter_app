CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  price INTEGER NOT NULL CHECK (price >= 0),
  category TEXT NOT NULL,
  image_label TEXT NOT NULL,
  accent_color BIGINT NOT NULL,
  image_asset TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO products (
  id,
  name,
  description,
  price,
  category,
  image_label,
  accent_color,
  image_asset,
  sort_order
) VALUES
  (
    'cafe-sua-da',
    'Cà phê sữa đá',
    'Cà phê phin đậm, sữa đặc béo nhẹ, đá mát.',
    35000,
    'Cà phê',
    'Phin sữa',
    4286879872,
    NULL,
    10
  ),
  (
    'bac-xiu',
    'Bạc xỉu',
    'Sữa thơm béo hòa cùng vị cà phê dịu nhẹ.',
    39000,
    'Cà phê',
    'Bạc xỉu',
    4292458348,
    'images/products/images (1).jpg',
    20
  ),
  (
    'cafe-den-da',
    'Cà phê đen đá',
    'Đậm vị rang xay, hậu vị mạnh và tỉnh táo.',
    32000,
    'Cà phê',
    'Đen đá',
    4283773727,
    NULL,
    30
  ),
  (
    'cafe-muoi',
    'Cà phê muối',
    'Kem muối mịn, vị mặn nhẹ cân bằng cà phê.',
    45000,
    'Cà phê',
    'Muối kem',
    4289981025,
    NULL,
    40
  ),
  (
    'tra-dao-cam-sa',
    'Trà đào cam sả',
    'Trà thanh mát cùng đào, cam vàng và sả thơm.',
    42000,
    'Trà',
    'Đào cam',
    4293958218,
    NULL,
    50
  ),
  (
    'tra-sua-tran-chau',
    'Trà sữa trân châu',
    'Trà sữa ngọt dịu, trân châu dẻo dai.',
    48000,
    'Trà sữa',
    'Trân châu',
    4291332954,
    NULL,
    60
  ),
  (
    'matcha-da-xay',
    'Matcha đá xay',
    'Matcha thơm béo, đá xay mịn, kem tươi nhẹ.',
    55000,
    'Đá xay',
    'Matcha',
    4285377624,
    NULL,
    70
  ),
  (
    'banh-tiramisu',
    'Bánh tiramisu',
    'Bánh mềm, kem mascarpone và lớp cà phê thơm.',
    59000,
    'Bánh ngọt',
    'Tiramisu',
    4287323451,
    NULL,
    80
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  category = EXCLUDED.category,
  image_label = EXCLUDED.image_label,
  accent_color = EXCLUDED.accent_color,
  image_asset = EXCLUDED.image_asset,
  is_active = TRUE,
  sort_order = EXCLUDED.sort_order,
  updated_at = NOW();

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  email TEXT UNIQUE,
  role INTEGER NOT NULL DEFAULT 0 CHECK (role IN (0, 1)),
  -- SHA-256 hex digest generated with pgcrypto: encode(digest(password, 'sha256'), 'hex')
  password_hash TEXT NOT NULL,
  address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS app_users_phone_idx ON app_users (phone);
CREATE INDEX IF NOT EXISTS app_users_email_idx ON app_users (email);

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS role INTEGER NOT NULL DEFAULT 0;

ALTER TABLE app_users
  DROP CONSTRAINT IF EXISTS app_users_role_check;

ALTER TABLE app_users
  ADD CONSTRAINT app_users_role_check CHECK (role IN (0, 1));

INSERT INTO app_users (
  full_name,
  phone,
  email,
  role,
  password_hash,
  address
) VALUES (
  'Admin Coffee Viet',
  '0999999999',
  'admin@coffeeviet.local',
  1,
  encode(digest('admin123', 'sha256'), 'hex'),
  'Admin site'
)
ON CONFLICT (phone) DO UPDATE SET
  role = 1,
  password_hash = EXCLUDED.password_hash,
  updated_at = NOW();

CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  delivery_address TEXT NOT NULL,
  payment_method TEXT NOT NULL,
  subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
  delivery_fee INTEGER NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
  total INTEGER NOT NULL CHECK (total >= 0),
  status TEXT NOT NULL DEFAULT 'pending',
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  unit_price INTEGER NOT NULL CHECK (unit_price >= 0),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  size TEXT NOT NULL,
  sugar TEXT NOT NULL,
  ice TEXT NOT NULL,
  note TEXT,
  line_total INTEGER NOT NULL CHECK (line_total >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS orders_user_id_idx ON orders (user_id);
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON orders (created_at DESC);
CREATE INDEX IF NOT EXISTS order_items_order_id_idx ON order_items (order_id);

-- Delivery areas are managed data. IDs are stable and are never derived from
-- the display name, so existing orders remain valid when an admin renames an
-- area or changes its fee.
CREATE TABLE IF NOT EXISTS delivery_areas (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  shipping_fee INTEGER NOT NULL CHECK (shipping_fee >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO delivery_areas (id, name, shipping_fee, is_active) VALUES
  ('quan-1', 'Quận 1', 15000, TRUE),
  ('quan-3', 'Quận 3', 15000, TRUE),
  ('binh-thanh', 'Bình Thạnh', 18000, TRUE),
  ('phu-nhuan', 'Phú Nhuận', 18000, TRUE),
  ('go-vap', 'Gò Vấp', 22000, TRUE),
  ('tan-binh', 'Tân Bình', 22000, TRUE),
  ('tan-phu', 'Tân Phú', 25000, TRUE),
  ('thu-duc', 'Thành phố Thủ Đức', 30000, TRUE)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS address_detail TEXT,
  ADD COLUMN IF NOT EXISTS address_note TEXT,
  ADD COLUMN IF NOT EXISTS delivery_area_id TEXT;

-- Keep accounts created by the previous version usable without replacing the
-- existing address column.
UPDATE app_users
SET address_detail = address
WHERE address_detail IS NULL
  AND address IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'app_users_delivery_area_id_fkey'
  ) THEN
    ALTER TABLE app_users
      ADD CONSTRAINT app_users_delivery_area_id_fkey
      FOREIGN KEY (delivery_area_id) REFERENCES delivery_areas(id)
      ON DELETE RESTRICT;
  END IF;
END $$;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_area_id TEXT,
  ADD COLUMN IF NOT EXISTS delivery_area_name TEXT,
  ADD COLUMN IF NOT EXISTS cancel_reason TEXT,
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS preparing_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS delivering_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'orders_delivery_area_id_fkey'
  ) THEN
    ALTER TABLE orders
      ADD CONSTRAINT orders_delivery_area_id_fkey
      FOREIGN KEY (delivery_area_id) REFERENCES delivery_areas(id)
      ON DELETE RESTRICT;
  END IF;
END $$;

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders
  ADD CONSTRAINT orders_status_check
  CHECK (status IN (
    'pending',
    'confirmed',
    'preparing',
    'delivering',
    'completed',
    'cancelled'
  )) NOT VALID;

CREATE TABLE IF NOT EXISTS order_status_history (
  id BIGSERIAL PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status TEXT,
  to_status TEXT NOT NULL,
  note TEXT,
  changed_by_user_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO order_status_history (order_id, from_status, to_status, created_at)
SELECT id, NULL, status, created_at
FROM orders
WHERE NOT EXISTS (
  SELECT 1
  FROM order_status_history history
  WHERE history.order_id = orders.id
);

CREATE INDEX IF NOT EXISTS delivery_areas_active_idx
  ON delivery_areas (is_active, name);
CREATE INDEX IF NOT EXISTS app_users_delivery_area_id_idx
  ON app_users (delivery_area_id);
CREATE INDEX IF NOT EXISTS orders_delivery_area_id_idx
  ON orders (delivery_area_id);
CREATE INDEX IF NOT EXISTS orders_status_created_at_idx
  ON orders (status, created_at DESC);
CREATE INDEX IF NOT EXISTS order_status_history_order_id_idx
  ON order_status_history (order_id, created_at ASC);
