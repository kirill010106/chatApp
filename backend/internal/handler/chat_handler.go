package handler

import (
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/konst/chatapp-backend/internal/domain"
	"github.com/konst/chatapp-backend/internal/handler/middleware"
	"github.com/konst/chatapp-backend/internal/service"
)

type ChatHandler struct {
	chatSvc *service.ChatService
	msgSvc  *service.MessageService
}

func NewChatHandler(chatSvc *service.ChatService, msgSvc *service.MessageService) *ChatHandler {
	return &ChatHandler{chatSvc: chatSvc, msgSvc: msgSvc}
}

type createConversationRequest struct {
	OtherUserID string `json:"other_user_id"`
}

func (h *ChatHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	var req createConversationRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	otherID, err := uuid.Parse(req.OtherUserID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid other_user_id")
		return
	}

	conv, err := h.chatSvc.GetOrCreateDirectConversation(userID, otherID)
	if err != nil {
		if errors.Is(err, domain.ErrInvalidInput) {
			writeError(w, http.StatusBadRequest, "cannot create conversation with yourself")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to create conversation")
		return
	}

	writeJSON(w, http.StatusCreated, conv)
}

func (h *ChatHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	convs, err := h.chatSvc.ListConversations(userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list conversations")
		return
	}

	writeJSON(w, http.StatusOK, convs)
}

func (h *ChatHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	convIDStr := chi.URLParam(r, "id")
	convID, err := uuid.Parse(convIDStr)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid conversation id")
		return
	}

	if err := h.chatSvc.MarkRead(convID, userID); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to mark conversation as read")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *ChatHandler) Messages(w http.ResponseWriter, r *http.Request) {
	convIDStr := chi.URLParam(r, "id")
	convID, err := uuid.Parse(convIDStr)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid conversation id")
		return
	}

	var before time.Time
	if beforeStr := r.URL.Query().Get("before"); beforeStr != "" {
		before, err = time.Parse(time.RFC3339Nano, beforeStr)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid 'before' timestamp, use RFC3339")
			return
		}
	}

	limit := 30
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
			limit = l
		}
	}

	msgs, err := h.msgSvc.ListMessages(convID, before, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to get messages")
		return
	}

	writeJSON(w, http.StatusOK, msgs)
}
