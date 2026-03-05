package service

import (
	"errors"
	"fmt"

	"github.com/google/uuid"

	"github.com/konst/chatapp-backend/internal/domain"
)

type ChatService struct {
	convRepo domain.ConversationRepository
}

func NewChatService(convRepo domain.ConversationRepository) *ChatService {
	return &ChatService{convRepo: convRepo}
}

// GetOrCreateDirectConversation finds an existing 1-to-1 conversation between
// two users, or creates a new one if none exists.
func (s *ChatService) GetOrCreateDirectConversation(userID, otherUserID uuid.UUID) (*domain.Conversation, error) {
	if userID == otherUserID {
		return nil, domain.ErrInvalidInput
	}

	conv, err := s.convRepo.FindDirectConversation(userID, otherUserID)
	if err == nil {
		return conv, nil
	}
	if !errors.Is(err, domain.ErrNotFound) {
		return nil, fmt.Errorf("chat service find direct: %w", err)
	}

	// Create new conversation
	conv = &domain.Conversation{IsGroup: false}
	if err := s.convRepo.Create(conv); err != nil {
		return nil, fmt.Errorf("chat service create conv: %w", err)
	}

	if err := s.convRepo.AddParticipant(conv.ID, userID); err != nil {
		return nil, fmt.Errorf("chat service add participant 1: %w", err)
	}
	if err := s.convRepo.AddParticipant(conv.ID, otherUserID); err != nil {
		return nil, fmt.Errorf("chat service add participant 2: %w", err)
	}

	return conv, nil
}

func (s *ChatService) ListConversations(userID uuid.UUID) ([]*domain.ConversationWithDetails, error) {
	convs, err := s.convRepo.ListByUser(userID)
	if err != nil {
		return nil, fmt.Errorf("chat service list: %w", err)
	}
	return convs, nil
}

func (s *ChatService) GetParticipants(conversationID uuid.UUID) ([]uuid.UUID, error) {
	return s.convRepo.GetParticipants(conversationID)
}

func (s *ChatService) MarkRead(conversationID, userID uuid.UUID) error {
	return s.convRepo.MarkRead(conversationID, userID)
}
