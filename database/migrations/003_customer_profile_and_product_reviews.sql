-- Apply after database/schema.sql has created migrations 1 and 2.
-- This migration only adds the customer profile credentials guard and reviews.
CREATE TABLE IF NOT EXISTS product_reviews (
  id BIGSERIAL PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT NOT NULL,
  is_visible BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (CHAR_LENGTH(BTRIM(comment)) BETWEEN 2 AND 600)
);

CREATE UNIQUE INDEX IF NOT EXISTS product_reviews_product_user_key
  ON product_reviews (product_id, user_id);
CREATE INDEX IF NOT EXISTS product_reviews_product_visible_updated_idx
  ON product_reviews (product_id, is_visible, updated_at DESC);

CREATE OR REPLACE FUNCTION coffee_validate_account_credentials()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.phone := BTRIM(NEW.phone);
  NEW.email := NULLIF(LOWER(BTRIM(COALESCE(NEW.email, ''))), '');

  IF NEW.phone !~ '^(0|\+84)[0-9]{9,10}$' THEN
    RAISE EXCEPTION 'Số điện thoại chưa đúng định dạng.';
  END IF;
  IF NEW.email IS NOT NULL
    AND NEW.email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'Email chưa đúng định dạng.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION coffee_guard_product_review()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.comment := BTRIM(NEW.comment);

  IF NEW.rating < 1 OR NEW.rating > 5 THEN
    RAISE EXCEPTION 'Đánh giá phải từ 1 đến 5 sao.';
  END IF;
  IF CHAR_LENGTH(NEW.comment) < 2 OR CHAR_LENGTH(NEW.comment) > 600 THEN
    RAISE EXCEPTION 'Nhận xét phải có từ 2 đến 600 ký tự.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM app_users WHERE id = NEW.user_id AND is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'Tài khoản không còn hoạt động để gửi đánh giá.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM products WHERE id = NEW.product_id AND is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'Sản phẩm này không còn nhận đánh giá.';
  END IF;
  IF TG_OP = 'UPDATE'
    AND (
      NEW.product_id IS DISTINCT FROM OLD.product_id
      OR NEW.user_id IS DISTINCT FROM OLD.user_id
    ) THEN
    RAISE EXCEPTION 'Không thể chuyển đánh giá sang tài khoản hoặc sản phẩm khác.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS coffee_01_validate_account_credentials ON app_users;
CREATE TRIGGER coffee_01_validate_account_credentials
BEFORE INSERT OR UPDATE ON app_users
FOR EACH ROW EXECUTE FUNCTION coffee_validate_account_credentials();

DROP TRIGGER IF EXISTS coffee_10_guard_product_reviews ON product_reviews;
CREATE TRIGGER coffee_10_guard_product_reviews
BEFORE INSERT OR UPDATE ON product_reviews
FOR EACH ROW EXECUTE FUNCTION coffee_guard_product_review();

DROP TRIGGER IF EXISTS coffee_90_touch_product_reviews ON product_reviews;
CREATE TRIGGER coffee_90_touch_product_reviews
BEFORE UPDATE ON product_reviews
FOR EACH ROW EXECUTE FUNCTION coffee_touch_updated_at();

INSERT INTO schema_migrations (version, name)
VALUES (3, 'customer profile and product reviews')
ON CONFLICT (version) DO NOTHING;
