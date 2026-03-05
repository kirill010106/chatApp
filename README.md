# Chat App

Flutter + Go real-time messenger.

## Quick Start (Local Development)

```bash
# Start PostgreSQL and backend
docker compose up -d

# Run migrations
cd backend
export DATABASE_URL="postgres://chatapp:chatapp_local@localhost:5432/chatapp?sslmode=disable"
make migrate-up

# Run backend locally (alternative to Docker)
make run

# Run Flutter frontend
cd ../frontend
flutter run -d chrome --web-port=3000
```

## Stack

- **Backend:** Go, chi, pgx, sqlc, WebSocket (nhooyr.io/websocket)
- **Frontend:** Flutter, Riverpod, dio, go_router
- **Database:** PostgreSQL 16
- **Infra:** Docker Compose, Nginx

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/v1/auth/register | No | Create account |
| POST | /api/v1/auth/login | No | Login |
| POST | /api/v1/auth/refresh | No | Refresh token |
| GET | /api/v1/users/me | Yes | Current user |
| GET | /api/v1/users/search?q= | Yes | Search users |
| POST | /api/v1/conversations | Yes | Create conversation |
| GET | /api/v1/conversations | Yes | List conversations |
| GET | /api/v1/conversations/:id/messages | Yes | Message history |
| GET | /ws?token= | Yes | WebSocket |
