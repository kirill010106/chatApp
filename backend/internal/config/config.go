package config

import (
	"fmt"
	"time"

	"github.com/caarlos0/env/v11"
)

type Config struct {
	Port            int           `env:"PORT" envDefault:"8080"`
	DatabaseURL     string        `env:"DATABASE_URL,required"`
	JWTSecret       string        `env:"JWT_SECRET,required"`
	AccessTokenTTL  time.Duration `env:"ACCESS_TOKEN_TTL" envDefault:"15m"`
	RefreshTokenTTL time.Duration `env:"REFRESH_TOKEN_TTL" envDefault:"168h"`
	AllowedOrigins  []string      `env:"ALLOWED_ORIGINS" envSeparator:"," envDefault:"http://localhost:3000"`
	VAPIDPublicKey  string        `env:"VAPID_PUBLIC_KEY" envDefault:""`
	VAPIDPrivateKey string        `env:"VAPID_PRIVATE_KEY" envDefault:""`
	VAPIDEmail      string        `env:"VAPID_EMAIL" envDefault:"mailto:admin@chatapp.local"`

	// S3-compatible object storage
	S3Endpoint  string `env:"S3_ENDPOINT" envDefault:""`
	S3AccessKey string `env:"S3_ACCESS_KEY" envDefault:""`
	S3SecretKey string `env:"S3_SECRET_KEY" envDefault:""`
	S3Bucket    string `env:"S3_BUCKET" envDefault:"chatapp-media"`
	S3Region    string `env:"S3_REGION" envDefault:"us-east-1"`
}

func Load() (*Config, error) {
	cfg := &Config{}
	if err := env.Parse(cfg); err != nil {
		return nil, fmt.Errorf("config: parse env: %w", err)
	}
	return cfg, nil
}
