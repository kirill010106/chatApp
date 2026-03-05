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
}

func Load() (*Config, error) {
	cfg := &Config{}
	if err := env.Parse(cfg); err != nil {
		return nil, fmt.Errorf("config: parse env: %w", err)
	}
	return cfg, nil
}
