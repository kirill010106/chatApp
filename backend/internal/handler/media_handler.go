package handler

import (
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/konst/chatapp-backend/internal/handler/middleware"
	"github.com/konst/chatapp-backend/internal/service"
)

const maxUploadSize = 10 << 20 // 10 MB

// Allowed MIME types
var allowedMimeTypes = map[string]bool{
	"image/jpeg":      true,
	"image/png":       true,
	"image/gif":       true,
	"image/webp":      true,
	"video/mp4":       true,
	"video/webm":      true,
	"audio/mpeg":      true,
	"audio/ogg":       true,
	"audio/webm":      true,
	"application/pdf": true,
}

type MediaHandler struct {
	mediaSvc *service.MediaService
}

func NewMediaHandler(mediaSvc *service.MediaService) *MediaHandler {
	return &MediaHandler{mediaSvc: mediaSvc}
}

// Upload handles POST /api/v1/media/upload (multipart/form-data, field "file").
func (h *MediaHandler) Upload(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(uuid.UUID)

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		writeError(w, http.StatusBadRequest, "file too large (max 10 MB)")
		return
	}
	defer r.MultipartForm.RemoveAll()

	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "missing file field")
		return
	}
	defer file.Close()

	ct := header.Header.Get("Content-Type")
	if ct == "" {
		ct = "application/octet-stream"
	}
	// Take only the MIME type, drop parameters like charset
	ct = strings.SplitN(ct, ";", 2)[0]
	ct = strings.TrimSpace(ct)

	if !allowedMimeTypes[ct] {
		writeError(w, http.StatusBadRequest, "unsupported file type: "+ct)
		return
	}

	result, err := h.mediaSvc.Upload(r.Context(), userID, header.Filename, ct, header.Size, file)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to upload file")
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// Proxy handles GET /api/v1/media/* — streams the S3 object back to the client
// with proper Content-Type, avoiding CORS issues with direct S3 URLs.
func (h *MediaHandler) Proxy(w http.ResponseWriter, r *http.Request) {
	// Extract the S3 key from the URL path: /api/v1/media/uploads/...
	key := strings.TrimPrefix(r.URL.Path, "/api/v1/media/")
	if key == "" {
		writeError(w, http.StatusBadRequest, "missing key")
		return
	}

	body, contentType, size, err := h.mediaSvc.GetObject(r.Context(), key)
	if err != nil {
		writeError(w, http.StatusNotFound, "file not found")
		return
	}
	defer body.Close()

	if contentType != "" {
		w.Header().Set("Content-Type", contentType)
	}
	if size > 0 {
		w.Header().Set("Content-Length", fmt.Sprintf("%d", size))
	}
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")

	io.Copy(w, body)
}
