package service

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/SherClockHolmes/webpush-go"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/konst/chatapp-backend/internal/domain"
)

type PushService struct {
	repo       domain.PushSubscriptionRepository
	vapidPub   string
	vapidPriv  string
	vapidEmail string
}

func NewPushService(repo domain.PushSubscriptionRepository, vapidPublicKey, vapidPrivateKey, vapidEmail string) *PushService {
	return &PushService{
		repo:       repo,
		vapidPub:   vapidPublicKey,
		vapidPriv:  vapidPrivateKey,
		vapidEmail: vapidEmail,
	}
}

// VAPIDPublicKey returns the public key to send to clients.
func (s *PushService) VAPIDPublicKey() string {
	return s.vapidPub
}

// Subscribe saves a push subscription for a user.
func (s *PushService) Subscribe(userID uuid.UUID, endpoint, p256dh, auth string) error {
	sub := &domain.PushSubscription{
		UserID:   userID,
		Endpoint: endpoint,
		P256dh:   p256dh,
		Auth:     auth,
	}
	return s.repo.Save(sub)
}

// Unsubscribe removes a push subscription.
func (s *PushService) Unsubscribe(userID uuid.UUID, endpoint string) error {
	return s.repo.Delete(userID, endpoint)
}

// PushPayload is the JSON payload sent in the push notification.
type PushPayload struct {
	Title          string `json:"title"`
	Body           string `json:"body"`
	ConversationID string `json:"conversation_id"`
	SenderID       string `json:"sender_id"`
}

// SendNotification sends a push notification to all subscriptions of a user.
func (s *PushService) SendNotification(userID uuid.UUID, payload PushPayload) {
	subs, err := s.repo.GetByUser(userID)
	if err != nil {
		log.Error().Err(err).Str("user_id", userID.String()).Msg("push: failed to get subscriptions")
		return
	}

	if len(subs) == 0 {
		return
	}

	data, err := json.Marshal(payload)
	if err != nil {
		log.Error().Err(err).Msg("push: failed to marshal payload")
		return
	}

	for _, sub := range subs {
		go s.sendToSubscription(sub, data)
	}
}

func (s *PushService) sendToSubscription(sub *domain.PushSubscription, data []byte) {
	wSub := &webpush.Subscription{
		Endpoint: sub.Endpoint,
		Keys: webpush.Keys{
			P256dh: sub.P256dh,
			Auth:   sub.Auth,
		},
	}

	resp, err := webpush.SendNotification(data, wSub, &webpush.Options{
		Subscriber:      s.vapidEmail,
		VAPIDPublicKey:  s.vapidPub,
		VAPIDPrivateKey: s.vapidPriv,
		TTL:             60,
		HTTPClient:      &http.Client{Timeout: 10 * time.Second},
	})
	if err != nil {
		// Network timeout likely means push service is unreachable — remove subscription
		if strings.Contains(err.Error(), "timeout") || strings.Contains(err.Error(), "i/o timeout") {
			log.Warn().Str("endpoint", sub.Endpoint).Msg("push: push service unreachable, removing subscription")
			_ = s.repo.DeleteByEndpoint(sub.Endpoint)
		} else {
			log.Error().Err(err).Str("endpoint", sub.Endpoint).Msg("push: failed to send")
		}
		return
	}
	defer resp.Body.Close()

	// 410 Gone or 404 means the subscription is expired — remove it
	if resp.StatusCode == http.StatusGone || resp.StatusCode == http.StatusNotFound {
		log.Info().Str("endpoint", sub.Endpoint).Msg("push: subscription expired, removing")
		if err := s.repo.DeleteByEndpoint(sub.Endpoint); err != nil {
			log.Error().Err(err).Msg("push: failed to delete expired subscription")
		}
		return
	}

	if resp.StatusCode >= 400 {
		log.Warn().Int("status", resp.StatusCode).Str("endpoint", sub.Endpoint).Msg("push: unexpected status")
	} else {
		log.Debug().Int("status", resp.StatusCode).Str("endpoint", sub.Endpoint).Msg("push: sent successfully")
	}
}

// GenerateVAPIDKeys is a helper to generate new VAPID keys.
// Run once to get keys, then put them in env vars.
func GenerateVAPIDKeys() (privateKey, publicKey string, err error) {
	priv, pub, err := webpush.GenerateVAPIDKeys()
	if err != nil {
		return "", "", fmt.Errorf("failed to generate VAPID keys: %w", err)
	}
	return priv, pub, nil
}
