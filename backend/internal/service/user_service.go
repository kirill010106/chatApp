package service

import (
	"fmt"

	"github.com/google/uuid"

	"github.com/konst/chatapp-backend/internal/domain"
)

type UserService struct {
	userRepo domain.UserRepository
}

func NewUserService(userRepo domain.UserRepository) *UserService {
	return &UserService{userRepo: userRepo}
}

func (s *UserService) GetByID(id uuid.UUID) (*domain.User, error) {
	user, err := s.userRepo.GetByID(id)
	if err != nil {
		return nil, fmt.Errorf("user service get by id: %w", err)
	}
	return user, nil
}

func (s *UserService) Search(query string, limit int) ([]*domain.User, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	users, err := s.userRepo.Search(query, limit)
	if err != nil {
		return nil, fmt.Errorf("user service search: %w", err)
	}
	return users, nil
}
