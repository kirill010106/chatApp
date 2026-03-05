package postgres

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/konst/chatapp-backend/internal/domain"
	"github.com/konst/chatapp-backend/internal/repository/postgres/sqlcgen"
)

type MessageRepo struct {
	pool    *pgxpool.Pool
	queries *sqlcgen.Queries
}

func NewMessageRepo(pool *pgxpool.Pool) *MessageRepo {
	return &MessageRepo{pool: pool, queries: sqlcgen.New(pool)}
}

func (r *MessageRepo) Create(msg *domain.Message) error {
	row, err := r.queries.CreateMessage(context.Background(), sqlcgen.CreateMessageParams{
		ConversationID: uuidToPgUUID(msg.ConversationID),
		SenderID:       uuidToPgUUID(msg.SenderID),
		Content:        msg.Content,
		ContentType:    msg.ContentType,
	})
	if err != nil {
		return fmt.Errorf("message repo create: %w", err)
	}
	msg.ID = pgUUIDToUUID(row.ID)
	msg.CreatedAt = row.CreatedAt.Time
	return nil
}

func (r *MessageRepo) ListByConversation(conversationID uuid.UUID, before time.Time, limit int) ([]*domain.Message, error) {
	rows, err := r.queries.ListMessagesByConversation(context.Background(), sqlcgen.ListMessagesByConversationParams{
		ConversationID: uuidToPgUUID(conversationID),
		CreatedAt:      pgtype.Timestamptz{Time: before, Valid: true},
		Limit:          int32(limit),
	})
	if err != nil {
		return nil, fmt.Errorf("message repo list: %w", err)
	}
	msgs := make([]*domain.Message, 0, len(rows))
	for _, row := range rows {
		msgs = append(msgs, &domain.Message{
			ID:             pgUUIDToUUID(row.ID),
			ConversationID: pgUUIDToUUID(row.ConversationID),
			SenderID:       pgUUIDToUUID(row.SenderID),
			Content:        row.Content,
			ContentType:    row.ContentType,
			CreatedAt:      row.CreatedAt.Time,
		})
	}
	return msgs, nil
}
