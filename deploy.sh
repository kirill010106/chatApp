#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────
REGISTRY="${REGISTRY:-ghcr.io}"
REPO="${REPO:-kirill010106/chatapp}"
TAG="${TAG:-latest}"

# Production URLs baked into the frontend at build time
API_BASE_URL="${API_BASE_URL:?Set API_BASE_URL (e.g. http://185.65.200.160:80)}"
WS_URL="${WS_URL:?Set WS_URL (e.g. wss://185.65.200.160:80)}"

BACKEND_IMAGE="${REGISTRY}/${REPO}-backend:${TAG}"
FRONTEND_IMAGE="${REGISTRY}/${REPO}-frontend:${TAG}"

echo "==> Building backend image: ${BACKEND_IMAGE}"
docker build -t "${BACKEND_IMAGE}" ./backend

echo "==> Building frontend image: ${FRONTEND_IMAGE}"
docker build -t "${FRONTEND_IMAGE}" \
  --build-arg API_BASE_URL="${API_BASE_URL}" \
  --build-arg WS_URL="${WS_URL}" \
  ./frontend

echo "==> Pushing images to ${REGISTRY}..."
docker push "${BACKEND_IMAGE}"
docker push "${FRONTEND_IMAGE}"

echo ""
echo "Done! Images pushed:"
echo "  ${BACKEND_IMAGE}"
echo "  ${FRONTEND_IMAGE}"
echo ""
echo "On the server, run:"
echo "  docker compose -f docker-compose.prod.yml pull"
echo "  docker compose -f docker-compose.prod.yml up -d"
