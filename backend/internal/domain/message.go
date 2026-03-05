package domain

import (
	"time"

	"github.com/google/uuid"
)

type Message struct {
	ID             uuid.UUID `json:"id"`
	ConversationID uuid.UUID `json:"conversation_id"`
	SenderID       uuid.UUID `json:"sender_id"`
	Content        string    `json:"content"`
	ContentType    string    `json:"content_type"`
	CreatedAt      time.Time `json:"created_at"`
}

type MessageRepository interface {
	Create(msg *Message) error
	ListByConversation(conversationID uuid.UUID, before time.Time, limit int) ([]*Message, error)
}
