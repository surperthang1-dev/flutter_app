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
