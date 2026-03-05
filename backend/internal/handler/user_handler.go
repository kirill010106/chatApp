package handler

import (
	"net/http"

	"github.com/konst/chatapp-backend/internal/handler/middleware"
	"github.com/konst/chatapp-backend/internal/service"
)

type UserHandler struct {
	userSvc *service.UserService
}

func NewUserHandler(userSvc *service.UserService) *UserHandler {
	return &UserHandler{userSvc: userSvc}
}

func (h *UserHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	user, err := h.userSvc.GetByID(userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to get user")
		return
	}

	writeJSON(w, http.StatusOK, user)
}

func (h *UserHandler) Search(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		writeError(w, http.StatusBadRequest, "search query 'q' is required")
		return
	}

	users, err := h.userSvc.Search(query, 20)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "search failed")
		return
	}

	writeJSON(w, http.StatusOK, users)
}
