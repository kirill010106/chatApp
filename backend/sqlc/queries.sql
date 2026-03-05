-- name: CreateUser :one
INSERT INTO chatapp.users (username, email, password_hash, display_name)
VALUES ($1, $2, $3, $4)
RETURNING id, username, email, password_hash, display_name, avatar_url, created_at, updated_at;

-- name: GetUserByID :one
SELECT id, username, email, password_hash, display_name, avatar_url, created_at, updated_at
FROM chatapp.users WHERE id = $1;

-- name: GetUserByEmail :one
SELECT id, username, email, password_hash, display_name, avatar_url, created_at, updated_at
FROM chatapp.users WHERE email = $1;

-- name: GetUserByUsername :one
SELECT id, username, email, password_hash, display_name, avatar_url, created_at, updated_at
FROM chatapp.users WHERE username = $1;

-- name: SearchUsers :many
SELECT id, username, email, display_name, avatar_url, created_at, updated_at
FROM chatapp.users
WHERE username ILIKE '%' || $1 || '%' OR display_name ILIKE '%' || $1 || '%'
LIMIT $2;

-- name: CreateConversation :one
INSERT INTO chatapp.conversations (is_group, title)
VALUES ($1, $2)
RETURNING id, is_group, title, created_at, updated_at;

-- name: GetConversationByID :one
SELECT id, is_group, title, created_at, updated_at
FROM chatapp.conversations WHERE id = $1;

-- name: AddParticipant :exec
INSERT INTO chatapp.participants (conversation_id, user_id)
VALUES ($1, $2)
ON CONFLICT (conversation_id, user_id) DO NOTHING;

-- name: GetParticipants :many
SELECT user_id FROM chatapp.participants WHERE conversation_id = $1;

-- name: FindDirectConversation :one
SELECT c.id, c.is_group, c.title, c.created_at, c.updated_at
FROM chatapp.conversations c
JOIN chatapp.participants p1 ON p1.conversation_id = c.id
JOIN chatapp.participants p2 ON p2.conversation_id = c.id
WHERE p1.user_id = $1
  AND p2.user_id = $2
  AND c.is_group = false
LIMIT 1;

-- name: ListConversationsByUser :many
SELECT
    c.id, c.is_group, c.title, c.created_at, c.updated_at,
    u.id AS other_user_id, u.username AS other_username,
    u.display_name AS other_display_name, u.avatar_url AS other_avatar_url,
    m.id AS last_msg_id, COALESCE(m.content, '') AS last_msg_content,
    m.sender_id AS last_msg_sender_id, m.created_at AS last_msg_created_at,
    COALESCE((
        SELECT COUNT(*) FROM chatapp.messages msg
        WHERE msg.conversation_id = c.id AND msg.created_at > p.last_read_at
    ), 0)::int AS unread_count
FROM chatapp.conversations c
JOIN chatapp.participants p ON p.conversation_id = c.id AND p.user_id = $1
LEFT JOIN chatapp.participants p2 ON p2.conversation_id = c.id AND p2.user_id != $1
LEFT JOIN chatapp.users u ON u.id = p2.user_id
LEFT JOIN LATERAL (
    SELECT id, content, sender_id, created_at
    FROM chatapp.messages
    WHERE conversation_id = c.id
    ORDER BY created_at DESC
    LIMIT 1
) m ON true
ORDER BY COALESCE(m.created_at, c.created_at) DESC;

-- name: CreateMessage :one
INSERT INTO chatapp.messages (conversation_id, sender_id, content, content_type)
VALUES ($1, $2, $3, $4)
RETURNING id, conversation_id, sender_id, content, content_type, created_at;

-- name: ListMessagesByConversation :many
SELECT id, conversation_id, sender_id, content, content_type, created_at
FROM chatapp.messages
WHERE conversation_id = $1 AND created_at < $2
ORDER BY created_at DESC
LIMIT $3;

-- name: CreateRefreshToken :exec
INSERT INTO chatapp.refresh_tokens (user_id, token_hash, expires_at)
VALUES ($1, $2, $3);

-- name: GetRefreshTokenByHash :one
SELECT id, user_id, token_hash, expires_at, created_at
FROM chatapp.refresh_tokens WHERE token_hash = $1;

-- name: DeleteRefreshTokensByUser :exec
DELETE FROM chatapp.refresh_tokens WHERE user_id = $1;

-- name: DeleteRefreshTokenByHash :exec
DELETE FROM chatapp.refresh_tokens WHERE token_hash = $1;

-- name: IsParticipant :one
SELECT EXISTS(
    SELECT 1 FROM chatapp.participants WHERE conversation_id = $1 AND user_id = $2
) AS is_participant;

-- name: MarkConversationRead :exec
UPDATE chatapp.participants
SET last_read_at = now()
WHERE conversation_id = $1 AND user_id = $2;

-- name: GetLastReadAt :one
SELECT last_read_at FROM chatapp.participants
WHERE conversation_id = $1 AND user_id = $2;

-- name: CreatePushSubscription :exec
INSERT INTO chatapp.push_subscriptions (user_id, endpoint, p256dh, auth)
VALUES ($1, $2, $3, $4)
ON CONFLICT (user_id, endpoint) DO UPDATE
SET p256dh = EXCLUDED.p256dh, auth = EXCLUDED.auth;

-- name: DeletePushSubscription :exec
DELETE FROM chatapp.push_subscriptions
WHERE user_id = $1 AND endpoint = $2;

-- name: GetPushSubscriptionsByUser :many
SELECT id, user_id, endpoint, p256dh, auth, created_at
FROM chatapp.push_subscriptions
WHERE user_id = $1;

-- name: DeletePushSubscriptionByEndpoint :exec
DELETE FROM chatapp.push_subscriptions
WHERE endpoint = $1;
