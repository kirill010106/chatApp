package handler

import (
	"net/http"

	"nhooyr.io/websocket"

	"github.com/konst/chatapp-backend/internal/service"
	"github.com/konst/chatapp-backend/internal/ws"
	"github.com/rs/zerolog/log"
)

type WSHandler struct {
	hub     *ws.Hub
	authSvc *service.AuthService
	userSvc *service.UserService
	msgSvc  *service.MessageService
	chatSvc *service.ChatService
	pushSvc *service.PushService
}

func NewWSHandler(hub *ws.Hub, authSvc *service.AuthService, userSvc *service.UserService, msgSvc *service.MessageService, chatSvc *service.ChatService, pushSvc *service.PushService) *WSHandler {
	return &WSHandler{hub: hub, authSvc: authSvc, userSvc: userSvc, msgSvc: msgSvc, chatSvc: chatSvc, pushSvc: pushSvc}
}

func (h *WSHandler) HandleWS(w http.ResponseWriter, r *http.Request) {
	// Authenticate via query parameter
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "missing token", http.StatusUnauthorized)
		return
	}

	claims, err := h.authSvc.ValidateToken(token)
	if err != nil {
		http.Error(w, "invalid token", http.StatusUnauthorized)
		return
	}

	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		InsecureSkipVerify: true, // Allow all origins in dev; tighten in prod
	})
	if err != nil {
		log.Error().Err(err).Msg("ws: accept error")
		return
	}

	// Look up sender's display name for push notifications.
	senderName := ""
	if h.userSvc != nil {
		if u, err := h.userSvc.GetByID(claims.UserID); err == nil {
			if u.DisplayName != "" {
				senderName = u.DisplayName
			} else {
				senderName = u.Username
			}
		}
	}

	client := ws.NewClient(h.hub, claims.UserID, senderName, conn, h.msgSvc, h.chatSvc, h.pushSvc)
	h.hub.Register(client)

	go client.WritePump()
	go client.ReadPump()
}
