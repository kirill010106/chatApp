package ws

import (
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

// Hub maintains the set of active clients and broadcasts messages.
type Hub struct {
	clients    map[uuid.UUID]*Client
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[uuid.UUID]*Client),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

// Run starts the hub event loop. Must be called as a goroutine.
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			// Close existing connection for the same user (single-session)
			if old, ok := h.clients[client.UserID]; ok {
				close(old.send)
				h.clients[client.UserID] = client
				log.Info().Str("user_id", client.UserID.String()).Msg("ws: replaced existing connection")
			} else {
				h.clients[client.UserID] = client
				log.Info().Str("user_id", client.UserID.String()).Msg("ws: client registered")
			}
			h.mu.Unlock()

		case client := <-h.unregister:
			h.mu.Lock()
			if existing, ok := h.clients[client.UserID]; ok && existing == client {
				delete(h.clients, client.UserID)
				close(client.send)
				log.Info().Str("user_id", client.UserID.String()).Msg("ws: client unregistered")
			}
			h.mu.Unlock()
		}
	}
}

// Register adds a client to the hub.
func (h *Hub) Register(client *Client) {
	h.register <- client
}

// Unregister removes a client from the hub.
func (h *Hub) Unregister(client *Client) {
	h.unregister <- client
}

// SendToUser sends a message to a specific user if they're online.
func (h *Hub) SendToUser(userID uuid.UUID, data []byte) {
	h.mu.RLock()
	client, ok := h.clients[userID]
	h.mu.RUnlock()

	if ok {
		select {
		case client.send <- data:
		case <-time.After(2 * time.Second):
			log.Warn().Str("user_id", userID.String()).Msg("ws: send buffer full after 2s, dropping message")
		}
	}
}

// SendToUsers sends a message to multiple users.
func (h *Hub) SendToUsers(userIDs []uuid.UUID, data []byte) {
	for _, uid := range userIDs {
		h.SendToUser(uid, data)
	}
}

// IsOnline checks if a user has an active WebSocket connection.
func (h *Hub) IsOnline(userID uuid.UUID) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, ok := h.clients[userID]
	return ok
}
