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
	msgSvc  *service.MessageService
	chatSvc *service.ChatService
}

func NewWSHandler(hub *ws.Hub, authSvc *service.AuthService, msgSvc *service.MessageService, chatSvc *service.ChatService) *WSHandler {
	return &WSHandler{hub: hub, authSvc: authSvc, msgSvc: msgSvc, chatSvc: chatSvc}
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

	client := ws.NewClient(h.hub, claims.UserID, conn, h.msgSvc, h.chatSvc)
	h.hub.Register(client)

	go client.WritePump()
	go client.ReadPump()
}
