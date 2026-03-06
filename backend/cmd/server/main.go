package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/konst/chatapp-backend/internal/config"
	"github.com/konst/chatapp-backend/internal/handler"
	"github.com/konst/chatapp-backend/internal/handler/middleware"
	"github.com/konst/chatapp-backend/internal/repository/postgres"
	"github.com/konst/chatapp-backend/internal/service"
	"github.com/konst/chatapp-backend/internal/ws"
)

func main() {
	// Logging
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})

	// Config
	cfg, err := config.Load()
	if err != nil {
		log.Fatal().Err(err).Msg("failed to load config")
	}

	// Database
	pool, err := pgxpool.New(context.Background(), cfg.DatabaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to connect to database")
	}
	defer pool.Close()

	if err := pool.Ping(context.Background()); err != nil {
		log.Fatal().Err(err).Msg("failed to ping database")
	}
	log.Info().Msg("connected to database")

	// Repositories
	userRepo := postgres.NewUserRepo(pool)
	convRepo := postgres.NewConversationRepo(pool)
	msgRepo := postgres.NewMessageRepo(pool)
	refreshTokenRepo := postgres.NewRefreshTokenRepo(pool)
	pushSubRepo := postgres.NewPushSubscriptionRepo(pool)

	// Services
	authSvc := service.NewAuthService(userRepo, refreshTokenRepo, cfg.JWTSecret, cfg.AccessTokenTTL, cfg.RefreshTokenTTL)
	userSvc := service.NewUserService(userRepo)
	chatSvc := service.NewChatService(convRepo)
	msgSvc := service.NewMessageService(msgRepo, convRepo)

	// Push notifications service
	var pushSvc *service.PushService
	if cfg.VAPIDPublicKey != "" && cfg.VAPIDPrivateKey != "" {
		pushSvc = service.NewPushService(pushSubRepo, cfg.VAPIDPublicKey, cfg.VAPIDPrivateKey, cfg.VAPIDEmail)
		log.Info().Msg("web push notifications enabled")
	} else {
		log.Warn().Msg("VAPID keys not set — web push notifications disabled")
	}

	// Media (S3) service
	var mediaSvc *service.MediaService
	if cfg.S3Endpoint != "" && cfg.S3AccessKey != "" {
		var err error
		mediaSvc, err = service.NewMediaService(cfg.S3Endpoint, cfg.S3AccessKey, cfg.S3SecretKey, cfg.S3Bucket, cfg.S3Region)
		if err != nil {
			log.Fatal().Err(err).Msg("failed to init media service")
		}
		log.Info().Str("bucket", cfg.S3Bucket).Msg("S3 media service enabled")
	} else {
		log.Warn().Msg("S3 credentials not set — media uploads disabled")
	}

	// WebSocket Hub
	hub := ws.NewHub()
	go hub.Run()

	// Handlers
	authHandler := handler.NewAuthHandler(authSvc)
	userHandler := handler.NewUserHandler(userSvc)
	chatHandler := handler.NewChatHandler(chatSvc, msgSvc)
	wsHandler := handler.NewWSHandler(hub, authSvc, userSvc, msgSvc, chatSvc, pushSvc)
	pushHandler := handler.NewPushHandler(pushSvc)

	// Router
	r := chi.NewRouter()

	// Global middleware
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(middleware.Logger)
	r.Use(chimw.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   cfg.AllowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Public routes
	r.Post("/api/v1/auth/register", authHandler.Register)
	r.Post("/api/v1/auth/login", authHandler.Login)
	r.Post("/api/v1/auth/refresh", authHandler.Refresh)

	// Health check
	r.Get("/api/v1/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	// Public push endpoint (client needs VAPID key before auth)
	r.Get("/api/v1/push/vapid-key", pushHandler.VAPIDPublicKey)

	// WebSocket (auth via query param, not header)
	r.Get("/ws", wsHandler.HandleWS)

	// Media proxy — public (URLs are shared in messages, loaded by <img> tags)
	if mediaSvc != nil {
		mediaHandler := handler.NewMediaHandler(mediaSvc)
		r.Get("/api/v1/media/*", mediaHandler.Proxy)
	}

	// Protected routes
	r.Group(func(r chi.Router) {
		r.Use(middleware.Auth(authSvc))

		r.Get("/api/v1/users/me", userHandler.Me)
		r.Put("/api/v1/users/me", userHandler.UpdateProfile)
		r.Get("/api/v1/users/search", userHandler.Search)

		r.Post("/api/v1/conversations", chatHandler.Create)
		r.Get("/api/v1/conversations", chatHandler.List)
		r.Get("/api/v1/conversations/{id}/messages", chatHandler.Messages)
		r.Post("/api/v1/conversations/{id}/read", chatHandler.MarkRead)
		r.Get("/api/v1/conversations/{id}/read-status", chatHandler.ReadStatus)

		r.Post("/api/v1/push/subscribe", pushHandler.Subscribe)
		r.Post("/api/v1/push/unsubscribe", pushHandler.Unsubscribe)

		// Media upload (only if S3 is configured)
		if mediaSvc != nil {
			mediaHandler := handler.NewMediaHandler(mediaSvc)
			r.Post("/api/v1/media/upload", mediaHandler.Upload)
		}
	})

	// Server
	addr := fmt.Sprintf(":%d", cfg.Port)
	srv := &http.Server{
		Addr:         addr,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown
	go func() {
		log.Info().Str("addr", addr).Msg("server starting")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal().Err(err).Msg("server error")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info().Msg("shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal().Err(err).Msg("server forced shutdown")
	}
	log.Info().Msg("server stopped")
}
