package domain

import (
	"time"

	"github.com/google/uuid"
)

type Conversation struct {
	ID        uuid.UUID `json:"id"`
	IsGroup   bool      `json:"is_group"`
	Title     string    `json:"title,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type ConversationWithDetails struct {
	Conversation
	OtherUser   *User    `json:"other_user,omitempty"`
	LastMessage *Message `json:"last_message,omitempty"`
	UnreadCount int      `json:"unread_count"`
}

type Participant struct {
	ID             uuid.UUID `json:"id"`
	ConversationID uuid.UUID `json:"conversation_id"`
	UserID         uuid.UUID `json:"user_id"`
	JoinedAt       time.Time `json:"joined_at"`
}

type ConversationRepository interface {
	Create(conv *Conversation) error
	GetByID(id uuid.UUID) (*Conversation, error)
	AddParticipant(conversationID, userID uuid.UUID) error
	GetParticipants(conversationID uuid.UUID) ([]uuid.UUID, error)
	FindDirectConversation(userID1, userID2 uuid.UUID) (*Conversation, error)
	ListByUser(userID uuid.UUID) ([]*ConversationWithDetails, error)
	MarkRead(conversationID, userID uuid.UUID) error
	IsParticipant(conversationID, userID uuid.UUID) (bool, error)
	GetLastReadAt(conversationID, userID uuid.UUID) (time.Time, error)
}
