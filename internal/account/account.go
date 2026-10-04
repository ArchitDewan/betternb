package account

import (
	"context"
	"errors"
	"strings"
	"time"
)

const AccountStatusActive = "active"

var (
	ErrAccountNotFound = errors.New("account not found")
	ErrUnauthenticated = errors.New("unauthenticated")
)

// Identity is the verified, stable OIDC identity associated with an account.
// Email is intentionally not an account key.
type Identity struct {
	Issuer  string
	Subject string
}

func (i Identity) Valid() bool {
	return strings.TrimSpace(i.Issuer) != "" && strings.TrimSpace(i.Subject) != ""
}

type Account struct {
	ID        string    `json:"id"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

type Store interface {
	FindOrCreate(ctx context.Context, identity Identity) (Account, bool, error)
	Find(ctx context.Context, identity Identity) (Account, error)
}
