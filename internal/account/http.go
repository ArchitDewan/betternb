package account

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
)

type Authenticator interface {
	Authenticate(request *http.Request) (Identity, error)
}

type Config struct {
	Store         Store
	Authenticator Authenticator
	Logger        *slog.Logger
}

type api struct {
	store         Store
	authenticator Authenticator
	logger        *slog.Logger
}

func NewHandler(config Config) http.Handler {
	logger := config.Logger
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	a := &api{store: config.Store, authenticator: config.Authenticator, logger: logger}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", a.health)
	mux.Handle("GET /v1/accounts/me", a.authenticated(http.HandlerFunc(a.currentAccount)))
	mux.Handle("POST /v1/accounts/me", a.authenticated(http.HandlerFunc(a.bootstrapAccount)))
	return securityHeaders(mux)
}

type identityContextKey struct{}

func (a *api) authenticated(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		identity, err := a.authenticator.Authenticate(r)
		if err != nil || !identity.Valid() {
			w.Header().Set("WWW-Authenticate", `Bearer realm="betternb-api"`)
			writeError(w, http.StatusUnauthorized, "unauthorized", "A valid access token is required.")
			return
		}
		ctx := contextWithIdentity(r, identity)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func contextWithIdentity(r *http.Request, identity Identity) context.Context {
	return context.WithValue(r.Context(), identityContextKey{}, identity)
}

func identityFromRequest(r *http.Request) Identity {
	identity, _ := r.Context().Value(identityContextKey{}).(Identity)
	return identity
}

func (a *api) health(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = io.WriteString(w, "ok\n")
}

func (a *api) bootstrapAccount(w http.ResponseWriter, r *http.Request) {
	account, created, err := a.store.FindOrCreate(r.Context(), identityFromRequest(r))
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	if account.Status != AccountStatusActive {
		writeError(w, http.StatusForbidden, "account_unavailable", "This BetterNB account is not active.")
		return
	}
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	writeJSON(w, status, map[string]Account{"account": account})
}

func (a *api) currentAccount(w http.ResponseWriter, r *http.Request) {
	account, err := a.store.Find(r.Context(), identityFromRequest(r))
	if errors.Is(err, ErrAccountNotFound) {
		writeError(w, http.StatusNotFound, "account_not_found", "The authenticated identity has no BetterNB account.")
		return
	}
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	if account.Status != AccountStatusActive {
		writeError(w, http.StatusForbidden, "account_unavailable", "This BetterNB account is not active.")
		return
	}
	writeJSON(w, http.StatusOK, map[string]Account{"account": account})
}

func (a *api) internalError(w http.ResponseWriter, r *http.Request, err error) {
	a.logger.Error("account request failed", "method", r.Method, "path", r.URL.Path, "error", err)
	writeError(w, http.StatusInternalServerError, "internal_error", "Something went wrong.")
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{"error": map[string]string{"code": code, "message": message}})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		next.ServeHTTP(w, r)
	})
}
