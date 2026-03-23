ALTER TABLE identity_documents
  ADD COLUMN IF NOT EXISTS liveness_video_path TEXT,
  ADD COLUMN IF NOT EXISTS liveness_video_asset_id BIGINT REFERENCES uploaded_assets(id) ON DELETE SET NULL;
