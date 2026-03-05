package postgres

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/konst/chatapp-backend/internal/domain"
	"github.com/konst/chatapp-backend/internal/repository/postgres/sqlcgen"
)

type PushSubscriptionRepo struct {
	pool    *pgxpool.Pool
	queries *sqlcgen.Queries
}

func NewPushSubscriptionRepo(pool *pgxpool.Pool) *PushSubscriptionRepo {
	return &PushSubscriptionRepo{
		pool:    pool,
		queries: sqlcgen.New(pool),
	}
}

func (r *PushSubscriptionRepo) Save(sub *domain.PushSubscription) error {
	return r.queries.CreatePushSubscription(context.Background(), sqlcgen.CreatePushSubscriptionParams{
		UserID:   pgtype.UUID{Bytes: sub.UserID, Valid: true},
		Endpoint: sub.Endpoint,
		P256dh:   sub.P256dh,
		Auth:     sub.Auth,
	})
}

func (r *PushSubscriptionRepo) Delete(userID uuid.UUID, endpoint string) error {
	return r.queries.DeletePushSubscription(context.Background(), sqlcgen.DeletePushSubscriptionParams{
		UserID:   pgtype.UUID{Bytes: userID, Valid: true},
		Endpoint: endpoint,
	})
}

func (r *PushSubscriptionRepo) DeleteByEndpoint(endpoint string) error {
	return r.queries.DeletePushSubscriptionByEndpoint(context.Background(), endpoint)
}

func (r *PushSubscriptionRepo) GetByUser(userID uuid.UUID) ([]*domain.PushSubscription, error) {
	rows, err := r.queries.GetPushSubscriptionsByUser(context.Background(), pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, err
	}

	subs := make([]*domain.PushSubscription, len(rows))
	for i, row := range rows {
		subs[i] = &domain.PushSubscription{
			ID:        row.ID.Bytes,
			UserID:    row.UserID.Bytes,
			Endpoint:  row.Endpoint,
			P256dh:    row.P256dh,
			Auth:      row.Auth,
			CreatedAt: row.CreatedAt.Time,
		}
	}
	return subs, nil
}
