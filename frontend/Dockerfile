# Build stage — Flutter web
FROM ghcr.io/cirruslabs/flutter:3.29.0 AS builder
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
ARG API_BASE_URL=""
ARG WS_URL=""
RUN flutter build web \
    --release \
    --dart-define=API_BASE_URL=$API_BASE_URL \
    --dart-define=WS_URL=$WS_URL

# Run stage — Nginx
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
