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

-- Data-integrity triggers. Flutter validates these rules for a friendly UX;
-- the database repeats the critical checks so direct SQL cannot corrupt orders.
UPDATE app_users
SET address_note = 'Chưa cập nhật'
WHERE NULLIF(BTRIM(COALESCE(address_note, '')), '') IS NULL;

ALTER TABLE app_users
  ALTER COLUMN address_note SET NOT NULL;

CREATE OR REPLACE FUNCTION coffee_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_normalize_delivery_area()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.name := BTRIM(NEW.name);
  IF COALESCE(NEW.name, '') = '' THEN
    RAISE EXCEPTION 'Tên khu vực giao hàng không được để trống.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_normalize_product()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.name := BTRIM(NEW.name);
  NEW.description := BTRIM(NEW.description);
  NEW.category := BTRIM(NEW.category);
  NEW.image_label := BTRIM(NEW.image_label);

  IF COALESCE(NEW.name, '') = ''
    OR COALESCE(NEW.description, '') = ''
    OR COALESCE(NEW.category, '') = ''
    OR COALESCE(NEW.image_label, '') = '' THEN
    RAISE EXCEPTION 'Thông tin sản phẩm không được để trống.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_validate_customer_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.full_name := BTRIM(NEW.full_name);
  NEW.phone := BTRIM(NEW.phone);
  NEW.email := NULLIF(LOWER(BTRIM(COALESCE(NEW.email, ''))), '');
  NEW.address_detail := NULLIF(BTRIM(COALESCE(NEW.address_detail, '')), '');
  NEW.address_note := NULLIF(BTRIM(COALESCE(NEW.address_note, '')), '');

  IF NEW.address_detail IS NOT NULL THEN
    NEW.address := NEW.address_detail;
  END IF;

  IF NEW.role = 0 THEN
    IF NEW.address_detail IS NULL THEN
      RAISE EXCEPTION 'Khách hàng phải có số nhà và tên đường.';
    END IF;
    IF NEW.address_note IS NULL THEN
      RAISE EXCEPTION 'Khách hàng phải có ghi chú địa chỉ.';
    END IF;
    IF NEW.delivery_area_id IS NULL THEN
      RAISE EXCEPTION 'Khách hàng phải chọn khu vực giao hàng.';
    END IF;
    IF TG_OP = 'INSERT'
      OR NEW.delivery_area_id IS DISTINCT FROM OLD.delivery_area_id THEN
      IF NOT EXISTS (
        SELECT 1
        FROM delivery_areas
        WHERE id = NEW.delivery_area_id
          AND is_active = TRUE
      ) THEN
        RAISE EXCEPTION 'Khu vực giao hàng không còn hoạt động.';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_guard_order()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  area_name TEXT;
  area_fee INTEGER;
BEGIN
  NEW.customer_name := BTRIM(NEW.customer_name);
  NEW.customer_phone := BTRIM(NEW.customer_phone);
  NEW.delivery_address := BTRIM(NEW.delivery_address);
  NEW.payment_method := BTRIM(NEW.payment_method);
  NEW.note := NULLIF(BTRIM(COALESCE(NEW.note, '')), '');
  NEW.cancel_reason := NULLIF(BTRIM(COALESCE(NEW.cancel_reason, '')), '');

  IF COALESCE(NEW.customer_name, '') = ''
    OR COALESCE(NEW.customer_phone, '') = ''
    OR COALESCE(NEW.delivery_address, '') = ''
    OR COALESCE(NEW.payment_method, '') = '' THEN
    RAISE EXCEPTION 'Thông tin đơn hàng không được để trống.';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'pending' THEN
      RAISE EXCEPTION 'Đơn hàng mới phải ở trạng thái chờ xác nhận.';
    END IF;
    SELECT name, shipping_fee
    INTO area_name, area_fee
    FROM delivery_areas
    WHERE id = NEW.delivery_area_id
      AND is_active = TRUE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Khu vực giao hàng không còn hoạt động.';
    END IF;
    NEW.delivery_area_name := area_name;
    NEW.delivery_fee := area_fee;
    NEW.total := NEW.subtotal + NEW.delivery_fee;
    RETURN NEW;
  END IF;

  IF NEW.user_id IS DISTINCT FROM OLD.user_id
    OR NEW.delivery_area_id IS DISTINCT FROM OLD.delivery_area_id
    OR NEW.delivery_area_name IS DISTINCT FROM OLD.delivery_area_name
    OR NEW.customer_name IS DISTINCT FROM OLD.customer_name
    OR NEW.customer_phone IS DISTINCT FROM OLD.customer_phone
    OR NEW.delivery_address IS DISTINCT FROM OLD.delivery_address
    OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
    OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
    OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
    OR NEW.total IS DISTINCT FROM OLD.total THEN
    RAISE EXCEPTION 'Không thể sửa dữ liệu chụp nhanh của đơn hàng.';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status = 'pending' AND NEW.status IN ('confirmed', 'cancelled'))
      OR (OLD.status = 'confirmed' AND NEW.status IN ('preparing', 'cancelled'))
      OR (OLD.status = 'preparing' AND NEW.status IN ('delivering', 'cancelled'))
      OR (OLD.status = 'delivering' AND NEW.status = 'completed')
    ) THEN
      RAISE EXCEPTION 'Chuyển trạng thái đơn hàng không hợp lệ: % -> %.', OLD.status, NEW.status;
    END IF;

    IF NEW.status = 'cancelled' AND NEW.cancel_reason IS NULL THEN
      RAISE EXCEPTION 'Hủy đơn hàng phải có lý do.';
    END IF;

    IF NEW.status = 'confirmed' AND NEW.confirmed_at IS NULL THEN
      NEW.confirmed_at := NOW();
    ELSIF NEW.status = 'preparing' AND NEW.preparing_at IS NULL THEN
      NEW.preparing_at := NOW();
    ELSIF NEW.status = 'delivering' AND NEW.delivering_at IS NULL THEN
      NEW.delivering_at := NOW();
    ELSIF NEW.status = 'completed' AND NEW.completed_at IS NULL THEN
      NEW.completed_at := NOW();
    ELSIF NEW.status = 'cancelled' AND NEW.cancelled_at IS NULL THEN
      NEW.cancelled_at := NOW();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_guard_order_item()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.product_name := BTRIM(NEW.product_name);
  NEW.size := BTRIM(NEW.size);
  NEW.sugar := BTRIM(NEW.sugar);
  NEW.ice := BTRIM(NEW.ice);
  NEW.note := NULLIF(BTRIM(COALESCE(NEW.note, '')), '');

  IF COALESCE(NEW.product_name, '') = ''
    OR COALESCE(NEW.size, '') = ''
    OR COALESCE(NEW.sugar, '') = ''
    OR COALESCE(NEW.ice, '') = '' THEN
    RAISE EXCEPTION 'Thông tin món trong đơn hàng không được để trống.';
  END IF;

  NEW.line_total := NEW.unit_price * NEW.quantity;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_validate_order_totals()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  target_order_id TEXT;
  stored_subtotal INTEGER;
  stored_delivery_fee INTEGER;
  stored_total INTEGER;
  item_count BIGINT;
  item_subtotal BIGINT;
BEGIN
  IF TG_TABLE_NAME = 'orders' THEN
    target_order_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
  ELSE
    target_order_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.order_id ELSE NEW.order_id END;
  END IF;

  SELECT
    orders.subtotal,
    orders.delivery_fee,
    orders.total,
    COUNT(order_items.id),
    COALESCE(SUM(order_items.line_total), 0)
  INTO
    stored_subtotal,
    stored_delivery_fee,
    stored_total,
    item_count,
    item_subtotal
  FROM orders
  LEFT JOIN order_items ON order_items.order_id = orders.id
  WHERE orders.id = target_order_id
  GROUP BY orders.id, orders.subtotal, orders.delivery_fee, orders.total;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF item_count = 0 THEN
    RAISE EXCEPTION 'Đơn hàng phải có ít nhất một món.';
  END IF;
  IF item_subtotal <> stored_subtotal THEN
    RAISE EXCEPTION 'Tạm tính đơn hàng không khớp với các món đã đặt.';
  END IF;
  IF stored_total <> stored_subtotal + stored_delivery_fee THEN
    RAISE EXCEPTION 'Tổng thanh toán đơn hàng không hợp lệ.';
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_guard_order_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  current_status TEXT;
  latest_status TEXT;
BEGIN
  IF NEW.to_status NOT IN (
    'pending', 'confirmed', 'preparing', 'delivering', 'completed', 'cancelled'
  ) THEN
    RAISE EXCEPTION 'Trạng thái lịch sử đơn hàng không hợp lệ.';
  END IF;

  SELECT status INTO current_status FROM orders WHERE id = NEW.order_id;
  IF current_status IS DISTINCT FROM NEW.to_status THEN
    RAISE EXCEPTION 'Lịch sử phải khớp trạng thái hiện tại của đơn hàng.';
  END IF;

  SELECT to_status
  INTO latest_status
  FROM order_status_history
  WHERE order_id = NEW.order_id
  ORDER BY id DESC
  LIMIT 1;

  IF NEW.from_status IS NULL THEN
    IF latest_status IS NOT NULL OR NEW.to_status <> 'pending' THEN
      RAISE EXCEPTION 'Bản ghi lịch sử đầu tiên phải là trạng thái chờ xác nhận.';
    END IF;
  ELSIF latest_status IS DISTINCT FROM NEW.from_status THEN
    RAISE EXCEPTION 'Lịch sử trạng thái đơn hàng không liên tục.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS coffee_10_normalize_delivery_areas ON delivery_areas;
CREATE TRIGGER coffee_10_normalize_delivery_areas
BEFORE INSERT OR UPDATE ON delivery_areas
FOR EACH ROW EXECUTE FUNCTION coffee_normalize_delivery_area();

DROP TRIGGER IF EXISTS coffee_10_normalize_products ON products;
CREATE TRIGGER coffee_10_normalize_products
BEFORE INSERT OR UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION coffee_normalize_product();

DROP TRIGGER IF EXISTS coffee_10_validate_customer_profiles ON app_users;
CREATE TRIGGER coffee_10_validate_customer_profiles
BEFORE INSERT OR UPDATE ON app_users
FOR EACH ROW EXECUTE FUNCTION coffee_validate_customer_profile();

DROP TRIGGER IF EXISTS coffee_10_guard_orders ON orders;
CREATE TRIGGER coffee_10_guard_orders
BEFORE INSERT OR UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION coffee_guard_order();

DROP TRIGGER IF EXISTS coffee_10_guard_order_items ON order_items;
CREATE TRIGGER coffee_10_guard_order_items
BEFORE INSERT OR UPDATE ON order_items
FOR EACH ROW EXECUTE FUNCTION coffee_guard_order_item();

DROP TRIGGER IF EXISTS coffee_20_guard_order_history ON order_status_history;
CREATE TRIGGER coffee_20_guard_order_history
BEFORE INSERT ON order_status_history
FOR EACH ROW EXECUTE FUNCTION coffee_guard_order_history();

DROP TRIGGER IF EXISTS coffee_90_touch_delivery_areas ON delivery_areas;
CREATE TRIGGER coffee_90_touch_delivery_areas
BEFORE UPDATE ON delivery_areas
FOR EACH ROW EXECUTE FUNCTION coffee_touch_updated_at();

DROP TRIGGER IF EXISTS coffee_90_touch_products ON products;
CREATE TRIGGER coffee_90_touch_products
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION coffee_touch_updated_at();

DROP TRIGGER IF EXISTS coffee_90_touch_users ON app_users;
CREATE TRIGGER coffee_90_touch_users
BEFORE UPDATE ON app_users
FOR EACH ROW EXECUTE FUNCTION coffee_touch_updated_at();

DROP TRIGGER IF EXISTS coffee_90_touch_orders ON orders;
CREATE TRIGGER coffee_90_touch_orders
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION coffee_touch_updated_at();

DROP TRIGGER IF EXISTS coffee_40_validate_order_totals_from_orders ON orders;
CREATE CONSTRAINT TRIGGER coffee_40_validate_order_totals_from_orders
AFTER INSERT OR UPDATE OR DELETE ON orders
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION coffee_validate_order_totals();

DROP TRIGGER IF EXISTS coffee_40_validate_order_totals_from_items ON order_items;
CREATE CONSTRAINT TRIGGER coffee_40_validate_order_totals_from_items
AFTER INSERT OR UPDATE OR DELETE ON order_items
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION coffee_validate_order_totals();

-- Schema version 2: categories, discount snapshots and account activation.
CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO schema_migrations (version, name)
VALUES (1, 'baseline coffee ordering')
ON CONFLICT (version) DO NOTHING;

CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  image_path TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS categories_name_lower_key
  ON categories (LOWER(BTRIM(name)));
CREATE INDEX IF NOT EXISTS categories_active_name_idx
  ON categories (is_active, name);

INSERT INTO categories (id, name, description)
SELECT
  'legacy-' || MD5(LOWER(BTRIM(category))),
  BTRIM(category),
  ''
FROM (
  SELECT DISTINCT ON (LOWER(BTRIM(category))) category
  FROM products
  WHERE BTRIM(category) <> ''
  ORDER BY LOWER(BTRIM(category)), BTRIM(category)
) AS legacy_categories
ON CONFLICT DO NOTHING;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS category_id TEXT;

UPDATE products AS product
SET category_id = category.id
FROM categories AS category
WHERE product.category_id IS NULL
  AND LOWER(BTRIM(product.category)) = LOWER(BTRIM(category.name));

ALTER TABLE products
  ALTER COLUMN category_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'products_category_id_fkey'
  ) THEN
    ALTER TABLE products
      ADD CONSTRAINT products_category_id_fkey
      FOREIGN KEY (category_id) REFERENCES categories(id)
      ON DELETE RESTRICT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS products_category_id_active_idx
  ON products (category_id, is_active, sort_order);

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE app_users
SET is_active = TRUE
WHERE is_active IS NULL;

CREATE INDEX IF NOT EXISTS app_users_role_active_idx
  ON app_users (role, is_active, created_at DESC);

CREATE TABLE IF NOT EXISTS discount_codes (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  discount_type TEXT NOT NULL CHECK (discount_type IN ('fixed', 'percentage')),
  discount_value INTEGER NOT NULL CHECK (discount_value > 0),
  minimum_order_value INTEGER NOT NULL DEFAULT 0 CHECK (minimum_order_value >= 0),
  maximum_discount INTEGER CHECK (maximum_discount IS NULL OR maximum_discount >= 0),
  usage_limit INTEGER CHECK (usage_limit IS NULL OR usage_limit >= 0),
  used_count INTEGER NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (end_at > start_at),
  CHECK (discount_type <> 'percentage' OR discount_value <= 100)
);

CREATE UNIQUE INDEX IF NOT EXISTS discount_codes_code_upper_key
  ON discount_codes (UPPER(BTRIM(code)));
CREATE INDEX IF NOT EXISTS discount_codes_lookup_idx
  ON discount_codes (is_active, start_at, end_at);

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS discount_code_id TEXT,
  ADD COLUMN IF NOT EXISTS discount_code TEXT,
  ADD COLUMN IF NOT EXISTS discount_type TEXT,
  ADD COLUMN IF NOT EXISTS discount_value INTEGER,
  ADD COLUMN IF NOT EXISTS discount_amount INTEGER NOT NULL DEFAULT 0;

UPDATE orders
SET discount_amount = 0
WHERE discount_amount IS NULL;

ALTER TABLE orders
  ALTER COLUMN discount_amount SET NOT NULL;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_discount_amount_check;
ALTER TABLE orders
  ADD CONSTRAINT orders_discount_amount_check CHECK (discount_amount >= 0) NOT VALID;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'orders_discount_code_id_fkey'
  ) THEN
    ALTER TABLE orders
      ADD CONSTRAINT orders_discount_code_id_fkey
      FOREIGN KEY (discount_code_id) REFERENCES discount_codes(id)
      ON DELETE RESTRICT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS orders_discount_code_id_idx
  ON orders (discount_code_id);

CREATE OR REPLACE FUNCTION coffee_normalize_category()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.name := BTRIM(NEW.name);
  NEW.description := BTRIM(COALESCE(NEW.description, ''));
  NEW.image_path := NULLIF(BTRIM(COALESCE(NEW.image_path, '')), '');
  IF COALESCE(NEW.name, '') = '' THEN
    RAISE EXCEPTION 'Tên danh mục không được để trống.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_normalize_product()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  category_name TEXT;
BEGIN
  NEW.name := BTRIM(NEW.name);
  NEW.description := BTRIM(NEW.description);
  NEW.category := BTRIM(NEW.category);
  NEW.image_label := BTRIM(NEW.image_label);

  IF COALESCE(NEW.name, '') = ''
    OR COALESCE(NEW.description, '') = ''
    OR COALESCE(NEW.category, '') = ''
    OR COALESCE(NEW.image_label, '') = '' THEN
    RAISE EXCEPTION 'Thông tin sản phẩm không được để trống.';
  END IF;
  SELECT name INTO category_name FROM categories WHERE id = NEW.category_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Danh mục sản phẩm không tồn tại.';
  END IF;
  NEW.category := category_name;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_normalize_discount_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.code := UPPER(BTRIM(NEW.code));
  NEW.description := BTRIM(COALESCE(NEW.description, ''));

  IF COALESCE(NEW.code, '') = '' THEN
    RAISE EXCEPTION 'Mã giảm giá không được để trống.';
  END IF;
  IF NEW.discount_value <= 0 THEN
    RAISE EXCEPTION 'Giá trị giảm phải lớn hơn 0.';
  END IF;
  IF NEW.discount_type = 'percentage' AND NEW.discount_value > 100 THEN
    RAISE EXCEPTION 'Mã giảm theo phần trăm không được vượt quá 100%%.';
  END IF;
  IF NEW.end_at <= NEW.start_at THEN
    RAISE EXCEPTION 'Ngày kết thúc phải sau ngày bắt đầu.';
  END IF;
  IF NEW.usage_limit IS NOT NULL AND NEW.usage_limit < NEW.used_count THEN
    RAISE EXCEPTION 'Giới hạn lượt dùng không thể nhỏ hơn lượt đã dùng.';
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.used_count < OLD.used_count THEN
    RAISE EXCEPTION 'Không thể giảm số lượt đã sử dụng của mã giảm giá.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_guard_account_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Không thể đổi vai trò tài khoản bằng thao tác này.';
  END IF;
  IF OLD.role = 1
    AND OLD.is_active = TRUE
    AND NEW.is_active = FALSE
    AND (
      SELECT COUNT(*)
      FROM app_users
      WHERE role = 1 AND is_active = TRUE
    ) <= 1 THEN
    RAISE EXCEPTION 'Không thể khóa quản trị viên cuối cùng.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_guard_order()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  area_name TEXT;
  area_fee INTEGER;
  active_code TEXT;
  active_type TEXT;
  active_value INTEGER;
  active_minimum INTEGER;
  active_maximum INTEGER;
  active_usage_limit INTEGER;
  active_used_count INTEGER;
  calculated_discount INTEGER;
BEGIN
  NEW.customer_name := BTRIM(NEW.customer_name);
  NEW.customer_phone := BTRIM(NEW.customer_phone);
  NEW.delivery_address := BTRIM(NEW.delivery_address);
  NEW.payment_method := BTRIM(NEW.payment_method);
  NEW.note := NULLIF(BTRIM(COALESCE(NEW.note, '')), '');
  NEW.cancel_reason := NULLIF(BTRIM(COALESCE(NEW.cancel_reason, '')), '');

  IF COALESCE(NEW.customer_name, '') = ''
    OR COALESCE(NEW.customer_phone, '') = ''
    OR COALESCE(NEW.delivery_address, '') = ''
    OR COALESCE(NEW.payment_method, '') = '' THEN
    RAISE EXCEPTION 'Thông tin đơn hàng không được để trống.';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'pending' THEN
      RAISE EXCEPTION 'Đơn hàng mới phải ở trạng thái chờ xác nhận.';
    END IF;
    SELECT name, shipping_fee
    INTO area_name, area_fee
    FROM delivery_areas
    WHERE id = NEW.delivery_area_id
      AND is_active = TRUE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Khu vực giao hàng không còn hoạt động.';
    END IF;
    NEW.delivery_area_name := area_name;
    NEW.delivery_fee := area_fee;

    IF NEW.discount_code_id IS NULL THEN
      NEW.discount_code := NULL;
      NEW.discount_type := NULL;
      NEW.discount_value := NULL;
      NEW.discount_amount := 0;
    ELSE
      SELECT
        code,
        discount_type,
        discount_value,
        minimum_order_value,
        maximum_discount,
        usage_limit,
        used_count
      INTO
        active_code,
        active_type,
        active_value,
        active_minimum,
        active_maximum,
        active_usage_limit,
        active_used_count
      FROM discount_codes
      WHERE id = NEW.discount_code_id
        AND is_active = TRUE
        AND start_at <= NOW()
        AND end_at >= NOW()
      FOR UPDATE;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Mã giảm giá không hợp lệ hoặc đã hết hạn.';
      END IF;
      IF NEW.subtotal < active_minimum THEN
        RAISE EXCEPTION 'Đơn hàng chưa đạt giá trị tối thiểu của mã giảm giá.';
      END IF;
      IF active_usage_limit IS NOT NULL AND active_used_count >= active_usage_limit THEN
        RAISE EXCEPTION 'Mã giảm giá đã hết lượt sử dụng.';
      END IF;
      calculated_discount := CASE
        WHEN active_type = 'fixed' THEN LEAST(active_value, NEW.subtotal)
        ELSE LEAST(
          (NEW.subtotal * active_value) / 100,
          COALESCE(active_maximum, (NEW.subtotal * active_value) / 100),
          NEW.subtotal
        )
      END;
      NEW.discount_code := active_code;
      NEW.discount_type := active_type;
      NEW.discount_value := active_value;
      NEW.discount_amount := calculated_discount;
    END IF;
    NEW.total := NEW.subtotal - NEW.discount_amount + NEW.delivery_fee;
    RETURN NEW;
  END IF;

  IF NEW.user_id IS DISTINCT FROM OLD.user_id
    OR NEW.delivery_area_id IS DISTINCT FROM OLD.delivery_area_id
    OR NEW.delivery_area_name IS DISTINCT FROM OLD.delivery_area_name
    OR NEW.customer_name IS DISTINCT FROM OLD.customer_name
    OR NEW.customer_phone IS DISTINCT FROM OLD.customer_phone
    OR NEW.delivery_address IS DISTINCT FROM OLD.delivery_address
    OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
    OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
    OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
    OR NEW.discount_code_id IS DISTINCT FROM OLD.discount_code_id
    OR NEW.discount_code IS DISTINCT FROM OLD.discount_code
    OR NEW.discount_type IS DISTINCT FROM OLD.discount_type
    OR NEW.discount_value IS DISTINCT FROM OLD.discount_value
    OR NEW.discount_amount IS DISTINCT FROM OLD.discount_amount
    OR NEW.total IS DISTINCT FROM OLD.total THEN
    RAISE EXCEPTION 'Không thể sửa dữ liệu chụp nhanh của đơn hàng.';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status = 'pending' AND NEW.status IN ('confirmed', 'cancelled'))
      OR (OLD.status = 'confirmed' AND NEW.status IN ('preparing', 'cancelled'))
      OR (OLD.status = 'preparing' AND NEW.status IN ('delivering', 'cancelled'))
      OR (OLD.status = 'delivering' AND NEW.status = 'completed')
    ) THEN
      RAISE EXCEPTION 'Chuyển trạng thái đơn hàng không hợp lệ: % -> %.', OLD.status, NEW.status;
    END IF;
    IF NEW.status = 'cancelled' AND NEW.cancel_reason IS NULL THEN
      RAISE EXCEPTION 'Hủy đơn hàng phải có lý do.';
    END IF;
    IF NEW.status = 'confirmed' AND NEW.confirmed_at IS NULL THEN
      NEW.confirmed_at := NOW();
    ELSIF NEW.status = 'preparing' AND NEW.preparing_at IS NULL THEN
      NEW.preparing_at := NOW();
    ELSIF NEW.status = 'delivering' AND NEW.delivering_at IS NULL THEN
      NEW.delivering_at := NOW();
    ELSIF NEW.status = 'completed' AND NEW.completed_at IS NULL THEN
      NEW.completed_at := NOW();
    ELSIF NEW.status = 'cancelled' AND NEW.cancelled_at IS NULL THEN
      NEW.cancelled_at := NOW();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_validate_order_totals()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  target_order_id TEXT;
  stored_subtotal INTEGER;
  stored_delivery_fee INTEGER;
  stored_discount_amount INTEGER;
  stored_total INTEGER;
  item_count BIGINT;
  item_subtotal BIGINT;
BEGIN
  IF TG_TABLE_NAME = 'orders' THEN
    target_order_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
  ELSE
    target_order_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.order_id ELSE NEW.order_id END;
  END IF;

  SELECT
    orders.subtotal,
    orders.delivery_fee,
    orders.discount_amount,
    orders.total,
    COUNT(order_items.id),
    COALESCE(SUM(order_items.line_total), 0)
  INTO
    stored_subtotal,
    stored_delivery_fee,
    stored_discount_amount,
    stored_total,
    item_count,
    item_subtotal
  FROM orders
  LEFT JOIN order_items ON order_items.order_id = orders.id
  WHERE orders.id = target_order_id
  GROUP BY
    orders.id,
    orders.subtotal,
    orders.delivery_fee,
    orders.discount_amount,
    orders.total;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  IF item_count = 0 THEN
    RAISE EXCEPTION 'Đơn hàng phải có ít nhất một món.';
  END IF;
  IF item_subtotal <> stored_subtotal THEN
    RAISE EXCEPTION 'Tạm tính đơn hàng không khớp với các món đã đặt.';
  END IF;
  IF stored_discount_amount < 0 OR stored_discount_amount > stored_subtotal THEN
    RAISE EXCEPTION 'Giá trị giảm giá của đơn hàng không hợp lệ.';
  END IF;
  IF stored_total <> stored_subtotal - stored_discount_amount + stored_delivery_fee THEN
    RAISE EXCEPTION 'Tổng thanh toán đơn hàng không hợp lệ.';
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_increment_discount_usage()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.discount_code_id IS NOT NULL THEN
    UPDATE discount_codes
    SET used_count = used_count + 1
    WHERE id = NEW.discount_code_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS coffee_10_normalize_categories ON categories;
CREATE TRIGGER coffee_10_normalize_categories
BEFORE INSERT OR UPDATE ON categories
FOR EACH ROW EXECUTE FUNCTION coffee_normalize_category();

DROP TRIGGER IF EXISTS coffee_90_touch_categories ON categories;
CREATE TRIGGER coffee_90_touch_categories
BEFORE UPDATE ON categories
FOR EACH ROW EXECUTE FUNCTION coffee_touch_updated_at();

DROP TRIGGER IF EXISTS coffee_10_normalize_discount_codes ON discount_codes;
CREATE TRIGGER coffee_10_normalize_discount_codes
BEFORE INSERT OR UPDATE ON discount_codes
FOR EACH ROW EXECUTE FUNCTION coffee_normalize_discount_code();

DROP TRIGGER IF EXISTS coffee_90_touch_discount_codes ON discount_codes;
CREATE TRIGGER coffee_90_touch_discount_codes
BEFORE UPDATE ON discount_codes
FOR EACH ROW EXECUTE FUNCTION coffee_touch_updated_at();

DROP TRIGGER IF EXISTS coffee_05_guard_account_activity ON app_users;
CREATE TRIGGER coffee_05_guard_account_activity
BEFORE UPDATE ON app_users
FOR EACH ROW EXECUTE FUNCTION coffee_guard_account_activity();

DROP TRIGGER IF EXISTS coffee_30_increment_discount_usage ON orders;
CREATE TRIGGER coffee_30_increment_discount_usage
AFTER INSERT ON orders
FOR EACH ROW EXECUTE FUNCTION coffee_increment_discount_usage();

INSERT INTO schema_migrations (version, name)
VALUES (2, 'categories discounts and account activation')
ON CONFLICT (version) DO NOTHING;
