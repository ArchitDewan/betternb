package chat

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

// Notebook is a persisted workspace with one continuing conversation.
type Notebook struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	CreatedAt time.Time `json:"created_at"`
}

var (
	ErrInvalidNotebook = errors.New("invalid notebook identifier")
	ErrNotFound        = errors.New("not found")
	notebookIDPattern  = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`)
)

// Message is one user-authored entry in a notebook conversation.
type Message struct {
	ID         string      `json:"id"`
	Text       string      `json:"text,omitempty"`
	Attachment *Attachment `json:"attachment,omitempty"`
	CreatedAt  time.Time   `json:"created_at"`
}

// Attachment identifies image data owned by a message and notebook.
type Attachment struct {
	ID        string `json:"id"`
	Filename  string `json:"filename"`
	MediaType string `json:"media_type"`
	Size      int64  `json:"size"`
}

// Image contains already validated image bytes ready to persist.
type Image struct {
	Filename  string
	MediaType string
	Data      []byte
}

// StoredAttachment is the byte representation returned for delivery.
type StoredAttachment struct {
	Attachment
	Data []byte
}

// Store persists development conversation data on the local filesystem.
// The interface is intentionally narrow so production storage can replace it.
type Store struct {
	root string
	mu   sync.RWMutex
}

func NewStore(root string) (*Store, error) {
	if root == "" {
		return nil, errors.New("data directory is required")
	}
	if err := os.MkdirAll(root, 0o700); err != nil {
		return nil, fmt.Errorf("create data directory: %w", err)
	}
	store := &Store{root: root}
	if err := store.migrateLegacyNotebooks(); err != nil {
		return nil, err
	}
	return store, nil
}

// EnsureNotebook creates a stable built-in notebook when it does not exist.
func (s *Store) EnsureNotebook(id, title string) (Notebook, error) {
	if err := validateNotebookID(id); err != nil {
		return Notebook{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if notebook, err := s.readNotebook(id); err == nil {
		return notebook, nil
	} else if !errors.Is(err, ErrNotFound) {
		return Notebook{}, err
	}
	return s.writeNotebook(Notebook{ID: id, Title: title, CreatedAt: time.Now().UTC()})
}

// CreateNotebook creates a new notebook with a user-facing default title.
func (s *Store) CreateNotebook() (Notebook, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	notebooks, err := s.listNotebooks()
	if err != nil {
		return Notebook{}, err
	}
	title := availableNotebookTitle(notebooks)
	for {
		id, err := randomID()
		if err != nil {
			return Notebook{}, err
		}
		if _, err := s.readNotebook(id); errors.Is(err, ErrNotFound) {
			return s.writeNotebook(Notebook{ID: id, Title: title, CreatedAt: time.Now().UTC()})
		} else if err != nil {
			return Notebook{}, err
		}
	}
}

func (s *Store) Notebook(id string) (Notebook, error) {
	if err := validateNotebookID(id); err != nil {
		return Notebook{}, err
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.readNotebook(id)
}

func (s *Store) Notebooks() ([]Notebook, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.listNotebooks()
}

func (s *Store) Messages(notebookID string) ([]Message, error) {
	if err := validateNotebookID(notebookID); err != nil {
		return nil, err
	}

	s.mu.RLock()
	defer s.mu.RUnlock()
	if _, err := s.readNotebook(notebookID); err != nil {
		return nil, err
	}
	return s.readMessages(notebookID)
}

func (s *Store) AddMessage(notebookID, text string, image *Image) (Message, error) {
	if err := validateNotebookID(notebookID); err != nil {
		return Message{}, err
	}
	text = strings.TrimSpace(text)
	if text == "" && image == nil {
		return Message{}, errors.New("message text or image is required")
	}

	messageID, err := randomID()
	if err != nil {
		return Message{}, err
	}
	message := Message{ID: messageID, Text: text, CreatedAt: time.Now().UTC()}

	s.mu.Lock()
	defer s.mu.Unlock()
	if _, err := s.readNotebook(notebookID); err != nil {
		return Message{}, err
	}

	notebookDir := s.notebookDir(notebookID)
	if err := os.MkdirAll(filepath.Join(notebookDir, "attachments"), 0o700); err != nil {
		return Message{}, fmt.Errorf("create notebook data directory: %w", err)
	}

	var attachmentPath string
	if image != nil {
		attachmentID, idErr := randomID()
		if idErr != nil {
			return Message{}, idErr
		}
		extension, extensionErr := mediaTypeExtension(image.MediaType)
		if extensionErr != nil {
			return Message{}, extensionErr
		}
		message.Attachment = &Attachment{
			ID:        attachmentID,
			Filename:  cleanFilename(image.Filename),
			MediaType: image.MediaType,
			Size:      int64(len(image.Data)),
		}
		attachmentPath = filepath.Join(notebookDir, "attachments", attachmentID+extension)
		if err := writeAtomic(attachmentPath, image.Data); err != nil {
			return Message{}, fmt.Errorf("store attachment: %w", err)
		}
	}

	messages, err := s.readMessages(notebookID)
	if err != nil {
		if attachmentPath != "" {
			_ = os.Remove(attachmentPath)
		}
		return Message{}, err
	}
	messages = append(messages, message)
	encoded, err := json.MarshalIndent(messages, "", "  ")
	if err != nil {
		if attachmentPath != "" {
			_ = os.Remove(attachmentPath)
		}
		return Message{}, fmt.Errorf("encode messages: %w", err)
	}
	if err := writeAtomic(filepath.Join(notebookDir, "messages.json"), encoded); err != nil {
		if attachmentPath != "" {
			_ = os.Remove(attachmentPath)
		}
		return Message{}, fmt.Errorf("store message: %w", err)
	}
	return message, nil
}

func (s *Store) Attachment(notebookID, attachmentID string) (StoredAttachment, error) {
	if err := validateNotebookID(notebookID); err != nil {
		return StoredAttachment{}, err
	}
	if !isHexID(attachmentID) {
		return StoredAttachment{}, ErrNotFound
	}

	s.mu.RLock()
	defer s.mu.RUnlock()
	if _, err := s.readNotebook(notebookID); err != nil {
		return StoredAttachment{}, err
	}
	messages, err := s.readMessages(notebookID)
	if err != nil {
		return StoredAttachment{}, err
	}
	for _, message := range messages {
		if message.Attachment == nil || message.Attachment.ID != attachmentID {
			continue
		}
		extension, err := mediaTypeExtension(message.Attachment.MediaType)
		if err != nil {
			return StoredAttachment{}, ErrNotFound
		}
		data, err := os.ReadFile(filepath.Join(s.notebookDir(notebookID), "attachments", attachmentID+extension))
		if errors.Is(err, os.ErrNotExist) {
			return StoredAttachment{}, ErrNotFound
		}
		if err != nil {
			return StoredAttachment{}, fmt.Errorf("read attachment: %w", err)
		}
		return StoredAttachment{Attachment: *message.Attachment, Data: data}, nil
	}
	return StoredAttachment{}, ErrNotFound
}

func (s *Store) readNotebook(id string) (Notebook, error) {
	data, err := os.ReadFile(filepath.Join(s.notebookDir(id), "notebook.json"))
	if errors.Is(err, os.ErrNotExist) {
		return Notebook{}, ErrNotFound
	}
	if err != nil {
		return Notebook{}, fmt.Errorf("read notebook: %w", err)
	}
	var notebook Notebook
	if err := json.Unmarshal(data, &notebook); err != nil {
		return Notebook{}, fmt.Errorf("decode notebook: %w", err)
	}
	if notebook.ID != id || strings.TrimSpace(notebook.Title) == "" {
		return Notebook{}, fmt.Errorf("invalid notebook metadata for %q", id)
	}
	return notebook, nil
}

func (s *Store) writeNotebook(notebook Notebook) (Notebook, error) {
	notebookDir := s.notebookDir(notebook.ID)
	if err := os.MkdirAll(filepath.Join(notebookDir, "attachments"), 0o700); err != nil {
		return Notebook{}, fmt.Errorf("create notebook data directory: %w", err)
	}
	encoded, err := json.MarshalIndent(notebook, "", "  ")
	if err != nil {
		return Notebook{}, fmt.Errorf("encode notebook: %w", err)
	}
	if err := writeAtomic(filepath.Join(notebookDir, "notebook.json"), encoded); err != nil {
		return Notebook{}, fmt.Errorf("store notebook: %w", err)
	}
	return notebook, nil
}

func (s *Store) listNotebooks() ([]Notebook, error) {
	entries, err := os.ReadDir(filepath.Join(s.root, "notebooks"))
	if errors.Is(err, os.ErrNotExist) {
		return []Notebook{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("list notebooks: %w", err)
	}
	notebooks := make([]Notebook, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() || validateNotebookID(entry.Name()) != nil {
			continue
		}
		notebook, err := s.readNotebook(entry.Name())
		if errors.Is(err, ErrNotFound) {
			continue
		}
		if err != nil {
			return nil, err
		}
		notebooks = append(notebooks, notebook)
	}
	sort.Slice(notebooks, func(i, j int) bool {
		if notebooks[i].CreatedAt.Equal(notebooks[j].CreatedAt) {
			return notebooks[i].Title < notebooks[j].Title
		}
		return notebooks[i].CreatedAt.Before(notebooks[j].CreatedAt)
	})
	return notebooks, nil
}

func (s *Store) migrateLegacyNotebooks() error {
	entries, err := os.ReadDir(filepath.Join(s.root, "notebooks"))
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("list legacy notebooks: %w", err)
	}
	for _, entry := range entries {
		if !entry.IsDir() || validateNotebookID(entry.Name()) != nil {
			continue
		}
		if _, err := s.readNotebook(entry.Name()); err == nil {
			continue
		} else if !errors.Is(err, ErrNotFound) {
			return err
		}
		if _, err := os.Stat(filepath.Join(s.notebookDir(entry.Name()), "messages.json")); errors.Is(err, os.ErrNotExist) {
			continue
		} else if err != nil {
			return fmt.Errorf("inspect legacy notebook: %w", err)
		}
		info, err := entry.Info()
		if err != nil {
			return fmt.Errorf("inspect legacy notebook directory: %w", err)
		}
		if _, err := s.writeNotebook(Notebook{ID: entry.Name(), Title: titleFromID(entry.Name()), CreatedAt: info.ModTime().UTC()}); err != nil {
			return fmt.Errorf("migrate legacy notebook: %w", err)
		}
	}
	return nil
}

func titleFromID(id string) string {
	words := strings.FieldsFunc(id, func(character rune) bool { return character == '-' || character == '_' })
	if len(words) == 0 {
		return "Notebook"
	}
	words[0] = strings.ToUpper(words[0][:1]) + words[0][1:]
	return strings.Join(words, " ")
}

func availableNotebookTitle(notebooks []Notebook) string {
	used := make(map[string]bool, len(notebooks))
	for _, notebook := range notebooks {
		used[notebook.Title] = true
	}
	if !used["New notebook"] {
		return "New notebook"
	}
	for number := 2; ; number++ {
		candidate := fmt.Sprintf("New notebook %d", number)
		if !used[candidate] {
			return candidate
		}
	}
}

func (s *Store) readMessages(notebookID string) ([]Message, error) {
	data, err := os.ReadFile(filepath.Join(s.notebookDir(notebookID), "messages.json"))
	if errors.Is(err, os.ErrNotExist) {
		return []Message{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read messages: %w", err)
	}
	var messages []Message
	if err := json.Unmarshal(data, &messages); err != nil {
		return nil, fmt.Errorf("decode messages: %w", err)
	}
	return messages, nil
}

func (s *Store) notebookDir(notebookID string) string {
	return filepath.Join(s.root, "notebooks", notebookID)
}

func validateNotebookID(id string) error {
	if !notebookIDPattern.MatchString(id) {
		return ErrInvalidNotebook
	}
	return nil
}

func randomID() (string, error) {
	buffer := make([]byte, 16)
	if _, err := rand.Read(buffer); err != nil {
		return "", fmt.Errorf("generate identifier: %w", err)
	}
	return hex.EncodeToString(buffer), nil
}

func isHexID(id string) bool {
	if len(id) != 32 {
		return false
	}
	_, err := hex.DecodeString(id)
	return err == nil
}

func cleanFilename(name string) string {
	name = filepath.Base(strings.ReplaceAll(name, `\`, "/"))
	name = strings.TrimSpace(name)
	if name == "" || name == "." {
		return "pasted-image"
	}
	return name
}

func mediaTypeExtension(mediaType string) (string, error) {
	switch mediaType {
	case "image/png":
		return ".png", nil
	case "image/jpeg":
		return ".jpg", nil
	case "image/gif":
		return ".gif", nil
	case "image/webp":
		return ".webp", nil
	default:
		return "", fmt.Errorf("unsupported image media type %q", mediaType)
	}
}

func writeAtomic(destination string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(destination), 0o700); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(destination), ".betternb-*")
	if err != nil {
		return err
	}
	temporaryName := temporary.Name()
	defer func() {
		_ = temporary.Close()
		_ = os.Remove(temporaryName)
	}()
	if err := temporary.Chmod(0o600); err != nil {
		return err
	}
	if _, err := temporary.Write(data); err != nil {
		return err
	}
	if err := temporary.Sync(); err != nil {
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryName, destination)
}
