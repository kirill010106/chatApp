package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/konst/chatapp-backend/internal/domain"
	"github.com/konst/chatapp-backend/internal/repository/postgres/sqlcgen"
)

type ConversationRepo struct {
	pool    *pgxpool.Pool
	queries *sqlcgen.Queries
}

func NewConversationRepo(pool *pgxpool.Pool) *ConversationRepo {
	return &ConversationRepo{pool: pool, queries: sqlcgen.New(pool)}
}

func (r *ConversationRepo) Create(conv *domain.Conversation) error {
	row, err := r.queries.CreateConversation(context.Background(), sqlcgen.CreateConversationParams{
		IsGroup: conv.IsGroup,
		Title:   conv.Title,
	})
	if err != nil {
		return fmt.Errorf("conversation repo create: %w", err)
	}
	conv.ID = pgUUIDToUUID(row.ID)
	conv.CreatedAt = row.CreatedAt.Time
	conv.UpdatedAt = row.UpdatedAt.Time
	return nil
}

func (r *ConversationRepo) GetByID(id uuid.UUID) (*domain.Conversation, error) {
	row, err := r.queries.GetConversationByID(context.Background(), uuidToPgUUID(id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("conversation repo get by id: %w", err)
	}
	return &domain.Conversation{
		ID:        pgUUIDToUUID(row.ID),
		IsGroup:   row.IsGroup,
		Title:     row.Title,
		CreatedAt: row.CreatedAt.Time,
		UpdatedAt: row.UpdatedAt.Time,
	}, nil
}

func (r *ConversationRepo) AddParticipant(conversationID, userID uuid.UUID) error {
	err := r.queries.AddParticipant(context.Background(), sqlcgen.AddParticipantParams{
		ConversationID: uuidToPgUUID(conversationID),
		UserID:         uuidToPgUUID(userID),
	})
	if err != nil {
		return fmt.Errorf("conversation repo add participant: %w", err)
	}
	return nil
}

func (r *ConversationRepo) GetParticipants(conversationID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.queries.GetParticipants(context.Background(), uuidToPgUUID(conversationID))
	if err != nil {
		return nil, fmt.Errorf("conversation repo get participants: %w", err)
	}
	ids := make([]uuid.UUID, 0, len(rows))
	for _, row := range rows {
		ids = append(ids, pgUUIDToUUID(row))
	}
	return ids, nil
}

func (r *ConversationRepo) FindDirectConversation(userID1, userID2 uuid.UUID) (*domain.Conversation, error) {
	row, err := r.queries.FindDirectConversation(context.Background(), sqlcgen.FindDirectConversationParams{
		UserID:   uuidToPgUUID(userID1),
		UserID_2: uuidToPgUUID(userID2),
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("conversation repo find direct: %w", err)
	}
	return &domain.Conversation{
		ID:        pgUUIDToUUID(row.ID),
		IsGroup:   row.IsGroup,
		Title:     row.Title,
		CreatedAt: row.CreatedAt.Time,
		UpdatedAt: row.UpdatedAt.Time,
	}, nil
}

func (r *ConversationRepo) ListByUser(userID uuid.UUID) ([]*domain.ConversationWithDetails, error) {
	rows, err := r.queries.ListConversationsByUser(context.Background(), uuidToPgUUID(userID))
	if err != nil {
		return nil, fmt.Errorf("conversation repo list by user: %w", err)
	}
	convs := make([]*domain.ConversationWithDetails, 0, len(rows))
	for _, row := range rows {
		c := &domain.ConversationWithDetails{
			Conversation: domain.Conversation{
				ID:        pgUUIDToUUID(row.ID),
				IsGroup:   row.IsGroup,
				Title:     row.Title,
				CreatedAt: row.CreatedAt.Time,
				UpdatedAt: row.UpdatedAt.Time,
			},
			UnreadCount: int(row.UnreadCount),
		}

		if row.OtherUserID.Valid {
			c.OtherUser = &domain.User{
				ID:          pgUUIDToUUID(row.OtherUserID),
				Username:    row.OtherUsername.String,
				DisplayName: row.OtherDisplayName.String,
				AvatarURL:   row.OtherAvatarUrl.String,
			}
		}

		if row.LastMsgID.Valid {
			c.LastMessage = &domain.Message{
				ID:             pgUUIDToUUID(row.LastMsgID),
				ConversationID: pgUUIDToUUID(row.ID),
				SenderID:       pgUUIDToUUID(row.LastMsgSenderID),
				Content:        row.LastMsgContent,
				CreatedAt:      row.LastMsgCreatedAt.Time,
			}
		}

		convs = append(convs, c)
	}
	return convs, nil
}

func (r *ConversationRepo) IsParticipant(conversationID, userID uuid.UUID) (bool, error) {
	ok, err := r.queries.IsParticipant(context.Background(), sqlcgen.IsParticipantParams{
		ConversationID: uuidToPgUUID(conversationID),
		UserID:         uuidToPgUUID(userID),
	})
	if err != nil {
		return false, fmt.Errorf("conversation repo is participant: %w", err)
	}
	return ok, nil
}

func (r *ConversationRepo) MarkRead(conversationID, userID uuid.UUID) error {
	err := r.queries.MarkConversationRead(context.Background(), sqlcgen.MarkConversationReadParams{
		ConversationID: uuidToPgUUID(conversationID),
		UserID:         uuidToPgUUID(userID),
	})
	if err != nil {
		return fmt.Errorf("conversation repo mark read: %w", err)
	}
	return nil
}
