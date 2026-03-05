-- +goose Up
CREATE SCHEMA IF NOT EXISTS chatapp;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS chatapp.users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username      VARCHAR(50)  UNIQUE NOT NULL,
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT         NOT NULL,
    display_name  VARCHAR(100) NOT NULL DEFAULT '',
    avatar_url    TEXT         NOT NULL DEFAULT '',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chatapp.conversations (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    is_group   BOOLEAN     NOT NULL DEFAULT false,
    title      VARCHAR(255) NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chatapp.participants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chatapp.conversations(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES chatapp.users(id) ON DELETE CASCADE,
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS chatapp.messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID        NOT NULL REFERENCES chatapp.conversations(id) ON DELETE CASCADE,
    sender_id       UUID        NOT NULL REFERENCES chatapp.users(id) ON DELETE CASCADE,
    content         TEXT        NOT NULL,
    content_type    VARCHAR(20) NOT NULL DEFAULT 'text',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chatapp.refresh_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES chatapp.users(id) ON DELETE CASCADE,
    token_hash TEXT        UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON chatapp.messages (conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender               ON chatapp.messages (sender_id);
CREATE INDEX IF NOT EXISTS idx_participants_user             ON chatapp.participants (user_id);
CREATE INDEX IF NOT EXISTS idx_participants_conversation     ON chatapp.participants (conversation_id);
CREATE INDEX IF NOT EXISTS idx_users_email                   ON chatapp.users (email);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user           ON chatapp.refresh_tokens (user_id);

-- +goose Down
DROP TABLE IF EXISTS chatapp.refresh_tokens;
DROP TABLE IF EXISTS chatapp.messages;
DROP TABLE IF EXISTS chatapp.participants;
DROP TABLE IF EXISTS chatapp.conversations;
DROP TABLE IF EXISTS chatapp.users;
DROP SCHEMA IF EXISTS chatapp;
