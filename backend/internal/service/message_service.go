package service

import (
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/konst/chatapp-backend/internal/domain"
)

type MessageService struct {
	msgRepo  domain.MessageRepository
	convRepo domain.ConversationRepository
}

func NewMessageService(msgRepo domain.MessageRepository, convRepo domain.ConversationRepository) *MessageService {
	return &MessageService{msgRepo: msgRepo, convRepo: convRepo}
}

func (s *MessageService) SendMessage(senderID, conversationID uuid.UUID, content, contentType string) (*domain.Message, error) {
	if contentType == "" {
		contentType = "text"
	}

	msg := &domain.Message{
		ConversationID: conversationID,
		SenderID:       senderID,
		Content:        content,
		ContentType:    contentType,
	}

	if err := s.msgRepo.Create(msg); err != nil {
		return nil, fmt.Errorf("message service send: %w", err)
	}

	return msg, nil
}

func (s *MessageService) ListMessages(conversationID uuid.UUID, before time.Time, limit int) ([]*domain.Message, error) {
	if before.IsZero() {
		before = time.Now()
	}
	if limit <= 0 || limit > 100 {
		limit = 30
	}

	msgs, err := s.msgRepo.ListByConversation(conversationID, before, limit)
	if err != nil {
		return nil, fmt.Errorf("message service list: %w", err)
	}
	return msgs, nil
}
