package domain

import (
	"time"

	"github.com/google/uuid"
)

type PushSubscription struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	Endpoint  string    `json:"endpoint"`
	P256dh    string    `json:"p256dh"`
	Auth      string    `json:"auth"`
	CreatedAt time.Time `json:"created_at"`
}

type PushSubscriptionRepository interface {
	Save(sub *PushSubscription) error
	Delete(userID uuid.UUID, endpoint string) error
	DeleteByEndpoint(endpoint string) error
	GetByUser(userID uuid.UUID) ([]*PushSubscription, error)
}
