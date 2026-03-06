package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/konst/chatapp-backend/internal/domain"
	"github.com/konst/chatapp-backend/internal/repository/postgres/sqlcgen"
)

type UserRepo struct {
	pool    *pgxpool.Pool
	queries *sqlcgen.Queries
}

func NewUserRepo(pool *pgxpool.Pool) *UserRepo {
	return &UserRepo{pool: pool, queries: sqlcgen.New(pool)}
}

func (r *UserRepo) Create(user *domain.User) error {
	row, err := r.queries.CreateUser(context.Background(), sqlcgen.CreateUserParams{
		Username:     user.Username,
		Email:        user.Email,
		PasswordHash: user.PasswordHash,
		DisplayName:  user.DisplayName,
	})
	if err != nil {
		return fmt.Errorf("user repo create: %w", err)
	}
	user.ID = pgUUIDToUUID(row.ID)
	user.CreatedAt = row.CreatedAt.Time
	user.UpdatedAt = row.UpdatedAt.Time
	return nil
}

func (r *UserRepo) GetByID(id uuid.UUID) (*domain.User, error) {
	row, err := r.queries.GetUserByID(context.Background(), uuidToPgUUID(id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("user repo get by id: %w", err)
	}
	return sqlcUserToDomain(row), nil
}

func (r *UserRepo) GetByEmail(email string) (*domain.User, error) {
	row, err := r.queries.GetUserByEmail(context.Background(), email)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("user repo get by email: %w", err)
	}
	return sqlcUserToDomain(row), nil
}

func (r *UserRepo) GetByUsername(username string) (*domain.User, error) {
	row, err := r.queries.GetUserByUsername(context.Background(), username)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("user repo get by username: %w", err)
	}
	return sqlcUserToDomain(row), nil
}

func (r *UserRepo) Search(query string, limit int) ([]*domain.User, error) {
	rows, err := r.queries.SearchUsers(context.Background(), sqlcgen.SearchUsersParams{
		Column1: pgtype.Text{String: query, Valid: true},
		Limit:   int32(limit),
	})
	if err != nil {
		return nil, fmt.Errorf("user repo search: %w", err)
	}
	users := make([]*domain.User, 0, len(rows))
	for _, row := range rows {
		users = append(users, &domain.User{
			ID:          pgUUIDToUUID(row.ID),
			Username:    row.Username,
			Email:       row.Email,
			DisplayName: row.DisplayName,
			AvatarURL:   row.AvatarUrl,
			CreatedAt:   row.CreatedAt.Time,
			UpdatedAt:   row.UpdatedAt.Time,
		})
	}
	return users, nil
}

func (r *UserRepo) Update(user *domain.User) error {
	row, err := r.queries.UpdateUser(context.Background(), sqlcgen.UpdateUserParams{
		ID:          uuidToPgUUID(user.ID),
		DisplayName: user.DisplayName,
		AvatarUrl:   user.AvatarURL,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("user repo update: %w", err)
	}
	user.DisplayName = row.DisplayName
	user.AvatarURL = row.AvatarUrl
	user.UpdatedAt = row.UpdatedAt.Time
	return nil
}

func sqlcUserToDomain(row sqlcgen.ChatappUser) *domain.User {
	return &domain.User{
		ID:           pgUUIDToUUID(row.ID),
		Username:     row.Username,
		Email:        row.Email,
		PasswordHash: row.PasswordHash,
		DisplayName:  row.DisplayName,
		AvatarURL:    row.AvatarUrl,
		CreatedAt:    row.CreatedAt.Time,
		UpdatedAt:    row.UpdatedAt.Time,
	}
}

// UUID conversion helpers

func uuidToPgUUID(id uuid.UUID) pgtype.UUID {
	return pgtype.UUID{Bytes: id, Valid: true}
}

func pgUUIDToUUID(id pgtype.UUID) uuid.UUID {
	return uuid.UUID(id.Bytes)
}
