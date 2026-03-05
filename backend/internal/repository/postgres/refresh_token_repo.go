package postgres

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/konst/chatapp-backend/internal/domain"
	"github.com/konst/chatapp-backend/internal/repository/postgres/sqlcgen"
)

type RefreshTokenRepo struct {
	pool    *pgxpool.Pool
	queries *sqlcgen.Queries
}

func NewRefreshTokenRepo(pool *pgxpool.Pool) *RefreshTokenRepo {
	return &RefreshTokenRepo{pool: pool, queries: sqlcgen.New(pool)}
}

func (r *RefreshTokenRepo) Create(token *domain.RefreshToken) error {
	err := r.queries.CreateRefreshToken(context.Background(), sqlcgen.CreateRefreshTokenParams{
		UserID:    uuidToPgUUID(token.UserID),
		TokenHash: token.TokenHash,
		ExpiresAt: pgtype.Timestamptz{Time: token.ExpiresAt, Valid: true},
	})
	if err != nil {
		return fmt.Errorf("refresh token repo create: %w", err)
	}
	return nil
}

func (r *RefreshTokenRepo) GetByTokenHash(hash string) (*domain.RefreshToken, error) {
	row, err := r.queries.GetRefreshTokenByHash(context.Background(), hash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("refresh token repo get: %w", err)
	}
	return &domain.RefreshToken{
		ID:        pgUUIDToUUID(row.ID),
		UserID:    pgUUIDToUUID(row.UserID),
		TokenHash: row.TokenHash,
		ExpiresAt: row.ExpiresAt.Time,
		CreatedAt: row.CreatedAt.Time,
	}, nil
}

func (r *RefreshTokenRepo) DeleteByUserID(userID uuid.UUID) error {
	err := r.queries.DeleteRefreshTokensByUser(context.Background(), uuidToPgUUID(userID))
	if err != nil {
		return fmt.Errorf("refresh token repo delete by user: %w", err)
	}
	return nil
}

func (r *RefreshTokenRepo) DeleteByTokenHash(hash string) error {
	err := r.queries.DeleteRefreshTokenByHash(context.Background(), hash)
	if err != nil {
		return fmt.Errorf("refresh token repo delete by hash: %w", err)
	}
	return nil
}

// HashToken creates a SHA-256 hash of the given token string.
func HashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

// Helper to check if token is expired.
func IsTokenExpired(expiresAt time.Time) bool {
	return time.Now().After(expiresAt)
}
