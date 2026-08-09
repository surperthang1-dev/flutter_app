-- Apply after migration 004. This creates persistent in-app order notifications.
CREATE TABLE IF NOT EXISTS user_notifications (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (
    type IN ('order_created', 'order_delivering', 'order_completed')
  ),
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (order_id, type)
);

CREATE INDEX IF NOT EXISTS user_notifications_user_unread_created_idx
  ON user_notifications (user_id, is_read, created_at DESC);

CREATE OR REPLACE FUNCTION coffee_create_order_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  notification_type TEXT;
  notification_title TEXT;
  notification_message TEXT;
  short_order_id TEXT;
BEGIN
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  short_order_id := RIGHT(NEW.id, 8);
  IF TG_OP = 'INSERT' THEN
    notification_type := 'order_created';
    notification_title := 'Đặt hàng thành công';
    notification_message :=
      'Đơn #' || short_order_id || ' đã được tiếp nhận. Quán sẽ xác nhận sớm.';
  ELSIF NEW.status IS DISTINCT FROM OLD.status
    AND NEW.status = 'delivering' THEN
    notification_type := 'order_delivering';
    notification_title := 'Đơn hàng đang được giao';
    notification_message :=
      'Đơn #' || short_order_id || ' đã rời quán và đang trên đường đến bạn.';
  ELSIF NEW.status IS DISTINCT FROM OLD.status
    AND NEW.status = 'completed' THEN
    notification_type := 'order_completed';
    notification_title := 'Giao hàng thành công';
    notification_message :=
      'Đơn #' || short_order_id || ' đã hoàn thành. Hãy đánh giá những món bạn đã mua.';
  ELSE
    RETURN NEW;
  END IF;

  INSERT INTO user_notifications (
    user_id, type, order_id, title, message
  )
  VALUES (
    NEW.user_id,
    notification_type,
    NEW.id,
    notification_title,
    notification_message
  )
  ON CONFLICT (order_id, type) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS coffee_40_create_order_notifications ON orders;
CREATE TRIGGER coffee_40_create_order_notifications
AFTER INSERT OR UPDATE OF status ON orders
FOR EACH ROW EXECUTE FUNCTION coffee_create_order_notification();

INSERT INTO schema_migrations (version, name)
VALUES (5, 'customer order notifications')
ON CONFLICT (version) DO NOTHING;
