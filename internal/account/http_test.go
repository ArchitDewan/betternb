package account

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestBootstrapAccountCreatesThenReturnsStableAccount(t *testing.T) {
	createdAt := time.Date(2026, 10, 3, 15, 0, 0, 0, time.UTC)
	store := &stubStore{account: Account{ID: "account-1", Status: AccountStatusActive, CreatedAt: createdAt}}
	handler := NewHandler(Config{
		Store:         store,
		Authenticator: stubAuthenticator{identity: Identity{Issuer: "https://example.auth0.com/", Subject: "auth0|student"}},
	})

	first := serve(t, handler, http.MethodPost, "/v1/accounts/me")
	if first.Code != http.StatusCreated {
		t.Fatalf("first bootstrap status = %d, want %d; body: %s", first.Code, http.StatusCreated, first.Body.String())
	}
	assertAccountResponse(t, first, store.account)

	second := serve(t, handler, http.MethodPost, "/v1/accounts/me")
	if second.Code != http.StatusOK {
		t.Fatalf("second bootstrap status = %d, want %d; body: %s", second.Code, http.StatusOK, second.Body.String())
	}
	assertAccountResponse(t, second, store.account)

	if store.calls != 2 {
		t.Fatalf("FindOrCreate calls = %d, want 2", store.calls)
	}
	if store.lastIdentity != (Identity{Issuer: "https://example.auth0.com/", Subject: "auth0|student"}) {
		t.Errorf("identity = %#v, want verified issuer and subject", store.lastIdentity)
	}
}

func TestGetCurrentAccountRequiresExistingAccount(t *testing.T) {
	store := &stubStore{findErr: ErrAccountNotFound}
	handler := NewHandler(Config{
		Store:         store,
		Authenticator: stubAuthenticator{identity: Identity{Issuer: "issuer", Subject: "subject"}},
	})

	response := serve(t, handler, http.MethodGet, "/v1/accounts/me")
	if response.Code != http.StatusNotFound {
		t.Fatalf("GET account status = %d, want %d; body: %s", response.Code, http.StatusNotFound, response.Body.String())
	}
	assertErrorCode(t, response, "account_not_found")
}

func TestProtectedAccountRoutesRejectInvalidCredentialsBeforeStore(t *testing.T) {
	store := &stubStore{}
	handler := NewHandler(Config{
		Store:         store,
		Authenticator: stubAuthenticator{err: ErrUnauthenticated},
	})

	for _, method := range []string{http.MethodGet, http.MethodPost} {
		response := serve(t, handler, method, "/v1/accounts/me")
		if response.Code != http.StatusUnauthorized {
			t.Errorf("%s status = %d, want %d", method, response.Code, http.StatusUnauthorized)
		}
		assertErrorCode(t, response, "unauthorized")
		if got := response.Header().Get("WWW-Authenticate"); got == "" {
			t.Errorf("%s response is missing WWW-Authenticate", method)
		}
	}
	if store.calls != 0 || store.findCalls != 0 {
		t.Fatalf("store was called for unauthenticated requests: create=%d find=%d", store.calls, store.findCalls)
	}
}

func TestInactiveAccountCannotUnlockClient(t *testing.T) {
	store := &stubStore{account: Account{ID: "account-1", Status: "disabled"}}
	handler := NewHandler(Config{
		Store:         store,
		Authenticator: stubAuthenticator{identity: Identity{Issuer: "issuer", Subject: "subject"}},
	})

	response := serve(t, handler, http.MethodPost, "/v1/accounts/me")
	if response.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusForbidden)
	}
	assertErrorCode(t, response, "account_unavailable")
}

func TestHealthCheckIsPublic(t *testing.T) {
	handler := NewHandler(Config{
		Store:         &stubStore{},
		Authenticator: stubAuthenticator{err: ErrUnauthenticated},
	})
	response := serve(t, handler, http.MethodGet, "/healthz")
	if response.Code != http.StatusOK || response.Body.String() != "ok\n" {
		t.Fatalf("health response = %d %q, want 200 ok", response.Code, response.Body.String())
	}
}

func TestAccountStoreFailureUsesSafeErrorEnvelope(t *testing.T) {
	handler := NewHandler(Config{
		Store:         &stubStore{err: errors.New("database includes secret detail")},
		Authenticator: stubAuthenticator{identity: Identity{Issuer: "issuer", Subject: "subject"}},
	})
	response := serve(t, handler, http.MethodPost, "/v1/accounts/me")
	if response.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusInternalServerError)
	}
	assertErrorCode(t, response, "internal_error")
	if body := response.Body.String(); body == "" || contains(body, "secret detail") {
		t.Fatalf("unsafe error response: %q", body)
	}
}

type stubAuthenticator struct {
	identity Identity
	err      error
}

func (a stubAuthenticator) Authenticate(*http.Request) (Identity, error) {
	return a.identity, a.err
}

type stubStore struct {
	account      Account
	created      bool
	err          error
	findErr      error
	calls        int
	findCalls    int
	lastIdentity Identity
}

func (s *stubStore) FindOrCreate(_ context.Context, identity Identity) (Account, bool, error) {
	s.calls++
	s.lastIdentity = identity
	created := !s.created
	s.created = true
	return s.account, created, s.err
}

func (s *stubStore) Find(_ context.Context, identity Identity) (Account, error) {
	s.findCalls++
	s.lastIdentity = identity
	return s.account, s.findErr
}

func serve(t *testing.T, handler http.Handler, method, path string) *httptest.ResponseRecorder {
	t.Helper()
	request := httptest.NewRequest(method, path, nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

func assertAccountResponse(t *testing.T, response *httptest.ResponseRecorder, want Account) {
	t.Helper()
	var body struct {
		Account Account `json:"account"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode account response: %v; body: %s", err, response.Body.String())
	}
	if body.Account != want {
		t.Errorf("account = %#v, want %#v", body.Account, want)
	}
}

func assertErrorCode(t *testing.T, response *httptest.ResponseRecorder, want string) {
	t.Helper()
	var body struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode error response: %v; body: %s", err, response.Body.String())
	}
	if body.Error.Code != want {
		t.Errorf("error code = %q, want %q", body.Error.Code, want)
	}
}

func contains(value, fragment string) bool {
	for i := 0; i+len(fragment) <= len(value); i++ {
		if value[i:i+len(fragment)] == fragment {
			return true
		}
	}
	return false
}
