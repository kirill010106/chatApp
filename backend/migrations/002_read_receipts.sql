-- +goose Up
ALTER TABLE chatapp.participants ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ NOT NULL DEFAULT '1970-01-01T00:00:00Z';

-- +goose Down
ALTER TABLE chatapp.participants DROP COLUMN IF EXISTS last_read_at;
