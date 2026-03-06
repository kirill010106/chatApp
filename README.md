# Chat App

Real-time messenger — Flutter Web + Go backend.

## Architecture

```
Browser ─► Nginx (frontend container, port 80)
              ├─ /            → Flutter SPA
              ├─ /api/        → proxy to backend:8080
              └─ /ws          → proxy to backend:8080 (WebSocket upgrade)
           Backend (port 8080) ─► PostgreSQL
                               ─► S3-compatible storage (media)
```

## Stack

| Layer | Tech |
|-------|------|
| Backend | Go 1.24, chi v5, pgx/v5, sqlc, zerolog, webpush-go, aws-sdk-go-v2 |
| Frontend | Flutter 3.29 (Web), Riverpod, dio, go_router, package:web |
| Database | PostgreSQL 16 |
| Storage | S3-compatible (itecocloud / MinIO / AWS) |
| Infra | Docker Compose, Nginx |

## Prerequisites

- Docker & Docker Compose v2
- (optional) Go 1.24+ & Flutter 3.29+ for local development

## Quick Start

### 1. Clone & configure secrets

```bash
git clone https://github.com/kirill010106/chatApp.git
cd chatApp
cp .env.example .env
# Edit .env — fill in DATABASE_URL, JWT_SECRET, VAPID keys, S3 credentials
```

### 2. Generate VAPID keys (if you don't have them)

```bash
cd backend
go run cmd/genkeys/main.go
# Copy the output into .env: VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY
```

### 3. Run with Docker Compose

```bash
# Local development (frontend at http://localhost, API at http://localhost:8080)
docker compose up -d --build
```

Both services will start:
- **backend** — reads `.env`, listens on `:8080`
- **frontend** — Flutter SPA behind Nginx on `:80`, proxies `/api/` and `/ws` to backend

### 4. Run database migrations

Migrations are applied automatically by the backend on startup.

## Environment Variables

All secrets live in `.env` (never committed to git). See `.env.example` for the full list:

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | ✅ | PostgreSQL connection string |
| `JWT_SECRET` | ✅ | Secret for signing JWT tokens |
| `PORT` | — | Backend port (default: `8080`) |
| `ALLOWED_ORIGINS` | — | CORS origins (comma-separated) |
| `VAPID_PUBLIC_KEY` | — | Web Push public key |
| `VAPID_PRIVATE_KEY` | — | Web Push private key |
| `VAPID_EMAIL` | — | Contact email for VAPID |
| `S3_ENDPOINT` | — | S3-compatible endpoint URL |
| `S3_ACCESS_KEY` | — | S3 access key |
| `S3_SECRET_KEY` | — | S3 secret key |
| `S3_BUCKET` | — | S3 bucket name (default: `chatapp-media`) |
| `S3_REGION` | — | S3 region (default: `us-east-1`) |

> **Note:** If S3 variables are empty, media uploads are disabled gracefully. Same for VAPID — push notifications are disabled if keys are missing.

## Deployment (MakeCloud / VPS)

### Option A: Docker Compose on a VM

1. SSH into your server
2. Install Docker & Docker Compose
3. Clone the repo, create `.env` with production values
4. Set `API_BASE_URL` and `WS_URL` build args in `docker-compose.yml`:

```yaml
frontend:
  build:
    context: ./frontend
    args:
      API_BASE_URL: "https://your-domain.com"
      WS_URL: "wss://your-domain.com"
```

5. Run `docker compose up -d --build`
6. Point your domain (or reverse proxy) to port 80

### Option B: Separate containers (MakeCloud)

If the platform deploys containers individually:

**Backend:**
- Image: build from `./backend/Dockerfile`
- Port: `8080`
- Env vars: set all from `.env` in the platform dashboard

**Frontend:**
- Image: build from `./frontend/Dockerfile`
- Build args: `API_BASE_URL=https://api.your-domain.com`, `WS_URL=wss://api.your-domain.com`
- Port: `80`

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/auth/register` | No | Create account |
| POST | `/api/v1/auth/login` | No | Login |
| POST | `/api/v1/auth/refresh` | No | Refresh token |
| GET | `/api/v1/users/me` | Yes | Current user |
| GET | `/api/v1/users/search?q=` | Yes | Search users |
| POST | `/api/v1/conversations` | Yes | Create conversation |
| GET | `/api/v1/conversations` | Yes | List conversations |
| GET | `/api/v1/conversations/:id/messages` | Yes | Message history |
| POST | `/api/v1/media/upload` | Yes | Upload image/file (10 MB max) |
| GET | `/api/v1/media/*` | No | Proxy media from S3 |
| POST | `/api/v1/push/subscribe` | Yes | Register push subscription |
| GET | `/ws?token=` | Yes | WebSocket connection |

## Local Development (without Docker)

```bash
# Backend
cd backend
cp .env.example .env   # fill in values
go run cmd/server/main.go

# Frontend (separate terminal)
cd frontend
flutter run -d chrome --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=WS_URL=ws://localhost:8080
```

## Project Structure

```
chatApp/
├── .env.example          # Environment variable template
├── docker-compose.yml    # Orchestration (backend + frontend)
├── backend/
│   ├── Dockerfile
│   ├── cmd/
│   │   ├── server/       # Main entry point
│   │   ├── genkeys/      # VAPID key generator
│   │   └── s3init/       # S3 bucket initializer
│   ├── internal/
│   │   ├── config/       # Env config loader
│   │   ├── domain/       # Domain models
│   │   ├── handler/      # HTTP handlers + middleware
│   │   ├── repository/   # PostgreSQL repositories (sqlc)
│   │   ├── service/      # Business logic
│   │   └── ws/           # WebSocket hub + client
│   └── migrations/       # SQL migration files
└── frontend/
    ├── Dockerfile        # Multi-stage: Flutter build + Nginx
    ├── nginx.conf        # SPA routing + API/WS proxy
    ├── lib/
    │   ├── core/         # Constants, networking, router, theme
    │   ├── features/
    │   │   ├── auth/     # Login, register, token management
    │   │   ├── chat/     # Conversations, messages, WS, media, push
    │   │   └── profile/  # User profile
    │   └── shared/       # Reusable widgets
    └── web/              # index.html, service worker, manifest
```
