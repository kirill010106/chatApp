package handler

import (
	"errors"
	"net/http"

	"github.com/konst/chatapp-backend/internal/domain"
	"github.com/konst/chatapp-backend/internal/service"
)

type AuthHandler struct {
	authSvc *service.AuthService
}

func NewAuthHandler(authSvc *service.AuthService) *AuthHandler {
	return &AuthHandler{authSvc: authSvc}
}

type registerRequest struct {
	Username    string `json:"username"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"display_name"`
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type authResponse struct {
	User   *domain.User       `json:"user"`
	Tokens *service.TokenPair `json:"tokens"`
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Username == "" || req.Email == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "username, email, and password are required")
		return
	}

	if len(req.Password) < 8 {
		writeError(w, http.StatusBadRequest, "password must be at least 8 characters")
		return
	}

	if len(req.Username) < 3 {
		writeError(w, http.StatusBadRequest, "username must be at least 3 characters")
		return
	}

	user, tokens, err := h.authSvc.Register(req.Username, req.Email, req.Password, req.DisplayName)
	if err != nil {
		if errors.Is(err, domain.ErrAlreadyExists) {
			writeError(w, http.StatusConflict, "user with this email or username already exists")
			return
		}
		writeError(w, http.StatusInternalServerError, "registration failed")
		return
	}

	writeJSON(w, http.StatusCreated, authResponse{User: user, Tokens: tokens})
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Email == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "email and password are required")
		return
	}

	user, tokens, err := h.authSvc.Login(req.Email, req.Password)
	if err != nil {
		if errors.Is(err, domain.ErrUnauthorized) {
			writeError(w, http.StatusUnauthorized, "invalid email or password")
			return
		}
		writeError(w, http.StatusInternalServerError, "login failed")
		return
	}

	writeJSON(w, http.StatusOK, authResponse{User: user, Tokens: tokens})
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.RefreshToken == "" {
		writeError(w, http.StatusBadRequest, "refresh_token is required")
		return
	}

	tokens, err := h.authSvc.RefreshTokens(req.RefreshToken)
	if err != nil {
		if errors.Is(err, domain.ErrUnauthorized) {
			writeError(w, http.StatusUnauthorized, "invalid or expired refresh token")
			return
		}
		writeError(w, http.StatusInternalServerError, "token refresh failed")
		return
	}

	writeJSON(w, http.StatusOK, tokens)
}
