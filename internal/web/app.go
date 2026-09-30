package web

import (
	"bytes"
	"embed"
	"errors"
	"fmt"
	"html/template"
	"io"
	"io/fs"
	"log/slog"
	"mime"
	"net/http"
	"net/url"
	"path"
	"strings"
	"time"

	"github.com/ArchitDewan/betternb/internal/chat"
)

const (
	maxImageBytes = 10 << 20
	maxBodyBytes  = maxImageBytes + (1 << 20)
)

//go:embed templates/*.html assets/*
var embeddedFiles embed.FS

type Config struct {
	DataDir string
	Logger  *slog.Logger
}

type App struct {
	store    *chat.Store
	template *template.Template
	handler  http.Handler
	logger   *slog.Logger
}

type pageData struct {
	NotebookID string
	Messages   []chat.Message
	Error      string
	DraftText  string
}

func New(config Config) (*App, error) {
	store, err := chat.NewStore(config.DataDir)
	if err != nil {
		return nil, err
	}
	tmpl, err := template.New("pages").Funcs(template.FuncMap{
		"attachmentURL": func(notebookID, attachmentID string) string {
			return "/notebooks/" + url.PathEscape(notebookID) + "/attachments/" + url.PathEscape(attachmentID)
		},
	}).ParseFS(embeddedFiles, "templates/*.html")
	if err != nil {
		return nil, fmt.Errorf("parse templates: %w", err)
	}
	logger := config.Logger
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	app := &App{store: store, template: tmpl, logger: logger}

	assets, err := fs.Sub(embeddedFiles, "assets")
	if err != nil {
		return nil, fmt.Errorf("load assets: %w", err)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", app.home)
	mux.Handle("GET /assets/", http.StripPrefix("/assets/", http.FileServerFS(assets)))
	mux.HandleFunc("GET /notebooks/{notebookID}", app.notebook)
	mux.HandleFunc("POST /notebooks/{notebookID}/messages", app.createMessage)
	mux.HandleFunc("GET /notebooks/{notebookID}/attachments/{attachmentID}", app.attachment)
	app.handler = securityHeaders(mux)
	return app, nil
}

func (a *App) Handler() http.Handler {
	return a.handler
}

func (a *App) home(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	a.renderTemplate(w, http.StatusOK, "landing.html", nil)
}

func (a *App) notebook(w http.ResponseWriter, r *http.Request) {
	notebookID := r.PathValue("notebookID")
	messages, err := a.store.Messages(notebookID)
	if errors.Is(err, chat.ErrInvalidNotebook) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	a.renderNotebook(w, http.StatusOK, pageData{NotebookID: notebookID, Messages: messages})
}

func (a *App) createMessage(w http.ResponseWriter, r *http.Request) {
	notebookID := r.PathValue("notebookID")
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyBytes)
	if err := r.ParseMultipartForm(1 << 20); err != nil {
		a.renderValidationError(w, notebookID, "Choose an image that is 10 MiB or smaller.", "")
		return
	}
	if r.MultipartForm != nil {
		defer r.MultipartForm.RemoveAll()
	}

	text := strings.TrimSpace(r.FormValue("text"))
	image, validationError, err := uploadedImage(r)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	if validationError != "" {
		a.renderValidationError(w, notebookID, validationError, text)
		return
	}
	if text == "" && image == nil {
		a.renderValidationError(w, notebookID, "Add a message or paste an image before sending.", text)
		return
	}
	if _, err := a.store.AddMessage(notebookID, text, image); errors.Is(err, chat.ErrInvalidNotebook) {
		http.NotFound(w, r)
		return
	} else if err != nil {
		a.internalError(w, r, err)
		return
	}
	http.Redirect(w, r, "/notebooks/"+url.PathEscape(notebookID), http.StatusSeeOther)
}

func (a *App) attachment(w http.ResponseWriter, r *http.Request) {
	stored, err := a.store.Attachment(r.PathValue("notebookID"), r.PathValue("attachmentID"))
	if errors.Is(err, chat.ErrNotFound) || errors.Is(err, chat.ErrInvalidNotebook) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	disposition := mime.FormatMediaType("inline", map[string]string{"filename": stored.Filename})
	w.Header().Set("Content-Type", stored.MediaType)
	w.Header().Set("Content-Disposition", disposition)
	w.Header().Set("Cache-Control", "private, max-age=31536000, immutable")
	http.ServeContent(w, r, stored.Filename, time.Time{}, bytes.NewReader(stored.Data))
}

func uploadedImage(r *http.Request) (*chat.Image, string, error) {
	file, header, err := r.FormFile("image")
	if errors.Is(err, http.ErrMissingFile) {
		return nil, "", nil
	}
	if err != nil {
		return nil, "", fmt.Errorf("read image form field: %w", err)
	}
	defer file.Close()

	data, err := io.ReadAll(io.LimitReader(file, maxImageBytes+1))
	if err != nil {
		return nil, "", fmt.Errorf("read uploaded image: %w", err)
	}
	if len(data) > maxImageBytes {
		return nil, "Choose an image that is 10 MiB or smaller.", nil
	}
	mediaType := http.DetectContentType(data)
	if !allowedImageType(mediaType) {
		return nil, "Paste a PNG, JPEG, GIF, or WebP image.", nil
	}
	return &chat.Image{Filename: path.Base(strings.ReplaceAll(header.Filename, `\`, "/")), MediaType: mediaType, Data: data}, "", nil
}

func allowedImageType(mediaType string) bool {
	switch mediaType {
	case "image/png", "image/jpeg", "image/gif", "image/webp":
		return true
	default:
		return false
	}
}

func (a *App) renderValidationError(w http.ResponseWriter, notebookID, message, draftText string) {
	messages, err := a.store.Messages(notebookID)
	if errors.Is(err, chat.ErrInvalidNotebook) {
		http.Error(w, "Not found.", http.StatusNotFound)
		return
	}
	if err != nil {
		a.logger.Error("load messages for validation response", "notebook_id", notebookID, "error", err)
		http.Error(w, "Something went wrong.", http.StatusInternalServerError)
		return
	}
	a.renderNotebook(w, http.StatusUnprocessableEntity, pageData{
		NotebookID: notebookID,
		Messages:   messages,
		Error:      message,
		DraftText:  draftText,
	})
}

func (a *App) renderNotebook(w http.ResponseWriter, status int, data pageData) {
	a.renderTemplate(w, status, "notebook.html", data)
}

func (a *App) renderTemplate(w http.ResponseWriter, status int, name string, data any) {
	var output bytes.Buffer
	if err := a.template.ExecuteTemplate(&output, name, data); err != nil {
		a.logger.Error("render template", "template", name, "error", err)
		http.Error(w, "Something went wrong.", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	_, _ = output.WriteTo(w)
}

func (a *App) internalError(w http.ResponseWriter, r *http.Request, err error) {
	a.logger.Error("request failed", "method", r.Method, "path", r.URL.Path, "error", err)
	http.Error(w, "Something went wrong.", http.StatusInternalServerError)
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Security-Policy", "default-src 'self'; img-src 'self' blob:; style-src 'self'; script-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		next.ServeHTTP(w, r)
	})
}
