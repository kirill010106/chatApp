package service

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/konst/chatapp-backend/internal/domain"
)

type AuthService struct {
	userRepo         domain.UserRepository
	refreshTokenRepo domain.RefreshTokenRepository
	jwtSecret        []byte
	accessTTL        time.Duration
	refreshTTL       time.Duration
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

type Claims struct {
	UserID   uuid.UUID `json:"uid"`
	Username string    `json:"usr"`
	jwt.RegisteredClaims
}

func NewAuthService(
	userRepo domain.UserRepository,
	refreshTokenRepo domain.RefreshTokenRepository,
	jwtSecret string,
	accessTTL, refreshTTL time.Duration,
) *AuthService {
	return &AuthService{
		userRepo:         userRepo,
		refreshTokenRepo: refreshTokenRepo,
		jwtSecret:        []byte(jwtSecret),
		accessTTL:        accessTTL,
		refreshTTL:       refreshTTL,
	}
}

func (s *AuthService) Register(username, email, password, displayName string) (*domain.User, *TokenPair, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		return nil, nil, fmt.Errorf("auth: hash password: %w", err)
	}

	if displayName == "" {
		displayName = username
	}

	user := &domain.User{
		Username:     username,
		Email:        email,
		PasswordHash: string(hash),
		DisplayName:  displayName,
	}

	if err := s.userRepo.Create(user); err != nil {
		return nil, nil, fmt.Errorf("auth: create user: %w", err)
	}

	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *AuthService) Login(email, password string) (*domain.User, *TokenPair, error) {
	user, err := s.userRepo.GetByEmail(email)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return nil, nil, domain.ErrUnauthorized
		}
		return nil, nil, fmt.Errorf("auth: get user: %w", err)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return nil, nil, domain.ErrUnauthorized
	}

	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *AuthService) RefreshTokens(refreshToken string) (*TokenPair, error) {
	hash := hashToken(refreshToken)

	stored, err := s.refreshTokenRepo.GetByTokenHash(hash)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return nil, domain.ErrUnauthorized
		}
		return nil, fmt.Errorf("auth: get refresh token: %w", err)
	}

	if time.Now().After(stored.ExpiresAt) {
		_ = s.refreshTokenRepo.DeleteByTokenHash(hash)
		return nil, domain.ErrUnauthorized
	}

	// Delete old refresh token (rotation)
	_ = s.refreshTokenRepo.DeleteByTokenHash(hash)

	user, err := s.userRepo.GetByID(stored.UserID)
	if err != nil {
		return nil, fmt.Errorf("auth: get user for refresh: %w", err)
	}

	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, err
	}

	return tokens, nil
}

func (s *AuthService) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return s.jwtSecret, nil
	})
	if err != nil {
		return nil, domain.ErrUnauthorized
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, domain.ErrUnauthorized
	}

	return claims, nil
}

func (s *AuthService) generateTokens(user *domain.User) (*TokenPair, error) {
	// Access token
	now := time.Now()
	claims := &Claims{
		UserID:   user.ID,
		Username: user.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(s.accessTTL)),
			IssuedAt:  jwt.NewNumericDate(now),
			Subject:   user.ID.String(),
		},
	}

	accessToken, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(s.jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("auth: sign access token: %w", err)
	}

	// Refresh token (opaque)
	refreshTokenRaw := uuid.New().String()
	refreshHash := hashToken(refreshTokenRaw)

	rt := &domain.RefreshToken{
		UserID:    user.ID,
		TokenHash: refreshHash,
		ExpiresAt: now.Add(s.refreshTTL),
	}
	if err := s.refreshTokenRepo.Create(rt); err != nil {
		return nil, fmt.Errorf("auth: store refresh token: %w", err)
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshTokenRaw,
	}, nil
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}
