CREATE INDEX IF NOT EXISTS idx_conversation_participants_user_active
  ON conversation_participants (user_id, left_at, is_archived, conversation_id);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_visible
  ON messages (conversation_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_disputes_status_priority_created
  ON disputes (status, priority, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_disputes_assigned_status_created
  ON disputes (assigned_to_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transaction_declarations_user_channel_time
  ON transaction_settlement_declarations (
    declared_by_id,
    settlement_mode,
    payment_channel,
    occurred_at DESC
  );

CREATE INDEX IF NOT EXISTS idx_transaction_declarations_status_mode
  ON transaction_settlement_declarations (status, settlement_mode, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_properties_search_fts
  ON properties
  USING GIN (
    to_tsvector(
      'simple',
      COALESCE(title, '') || ' ' ||
      COALESCE(short_description, '') || ' ' ||
      COALESCE(description, '')
    )
  );

CREATE INDEX IF NOT EXISTS idx_property_locations_search_fts
  ON property_locations
  USING GIN (
    to_tsvector(
      'simple',
      COALESCE(region, '') || ' ' ||
      COALESCE(city, '') || ' ' ||
      COALESCE(district, '') || ' ' ||
      COALESCE(neighborhood, '') || ' ' ||
      COALESCE(landmark, '')
    )
  );

CREATE INDEX IF NOT EXISTS idx_property_locations_geo_covering
  ON property_locations (region, city, latitude, longitude);
