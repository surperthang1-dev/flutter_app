-- Apply after migration 003. This only prevents duplicate area names.
CREATE UNIQUE INDEX IF NOT EXISTS delivery_areas_name_lower_key
  ON delivery_areas (LOWER(BTRIM(name)));

INSERT INTO schema_migrations (version, name)
VALUES (4, 'delivery area creation')
ON CONFLICT (version) DO NOTHING;
