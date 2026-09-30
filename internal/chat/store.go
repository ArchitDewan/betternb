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
	"strings"
	"sync"
	"time"
)

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
	return &Store{root: root}, nil
}

func (s *Store) Messages(notebookID string) ([]Message, error) {
	if err := validateNotebookID(notebookID); err != nil {
		return nil, err
	}

	s.mu.RLock()
	defer s.mu.RUnlock()
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
