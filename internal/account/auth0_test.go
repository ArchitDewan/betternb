package account

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/auth0/go-jwt-middleware/v3/validator"
)

func TestAuth0AuthenticatorValidatesSignatureIssuerAudienceAndExpiry(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generate RSA key: %v", err)
	}
	var issuer string
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/.well-known/openid-configuration":
			_ = json.NewEncoder(w).Encode(map[string]string{
				"issuer": issuer, "jwks_uri": issuer + ".well-known/jwks.json",
			})
		case "/.well-known/jwks.json":
			_ = json.NewEncoder(w).Encode(map[string]any{"keys": []map[string]string{{
				"kty": "RSA", "kid": "test-key", "use": "sig", "alg": "RS256",
				"n": base64.RawURLEncoding.EncodeToString(key.PublicKey.N.Bytes()),
				"e": encodeExponent(key.PublicKey.E),
			}}})
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()
	issuer = server.URL + "/"

	authenticator, err := newAuth0Authenticator(issuer, "https://api.betternb.test", server.Client())
	if err != nil {
		t.Fatalf("NewAuth0Authenticator: %v", err)
	}
	now := time.Now()
	valid := signedJWT(t, key, map[string]any{
		"iss": issuer, "sub": "apple|student", "aud": "https://api.betternb.test",
		"iat": now.Unix(), "exp": now.Add(time.Minute).Unix(),
	})
	request := httptest.NewRequest(http.MethodGet, "/v1/accounts/me", nil)
	request.Header.Set("Authorization", "Bearer "+valid)
	identity, err := authenticator.Authenticate(request)
	if err != nil {
		_, validationErr := authenticator.validator.ValidateToken(request.Context(), valid)
		t.Fatalf("valid token rejected: %v (validator: %v)", err, validationErr)
	}
	if identity != (Identity{Issuer: issuer, Subject: "apple|student"}) {
		t.Errorf("identity = %#v", identity)
	}

	for name, claims := range map[string]map[string]any{
		"wrong audience": {"iss": issuer, "sub": "student", "aud": "wrong", "exp": now.Add(time.Minute).Unix()},
		"wrong issuer":   {"iss": "https://attacker.invalid/", "sub": "student", "aud": "https://api.betternb.test", "exp": now.Add(time.Minute).Unix()},
		"expired":        {"iss": issuer, "sub": "student", "aud": "https://api.betternb.test", "exp": now.Add(-time.Minute).Unix()},
	} {
		t.Run(name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, "/", nil)
			request.Header.Set("Authorization", "Bearer "+signedJWT(t, key, claims))
			if _, err := authenticator.Authenticate(request); !errors.Is(err, ErrUnauthenticated) {
				t.Fatalf("Authenticate error = %v, want ErrUnauthenticated", err)
			}
		})
	}
}

func TestAuth0AuthenticatorReturnsValidatedIssuerAndSubject(t *testing.T) {
	validated := &validator.ValidatedClaims{RegisteredClaims: validator.RegisteredClaims{
		Issuer:  "https://tenant.auth0.com/",
		Subject: "google-oauth2|student",
	}}
	authenticator := &Auth0Authenticator{validator: stubTokenValidator{claims: validated}}
	request := httptest.NewRequest("GET", "/v1/accounts/me", nil)
	request.Header.Set("Authorization", "Bearer signed-token")

	identity, err := authenticator.Authenticate(request)
	if err != nil {
		t.Fatalf("Authenticate: %v", err)
	}
	if identity != (Identity{Issuer: validated.RegisteredClaims.Issuer, Subject: validated.RegisteredClaims.Subject}) {
		t.Errorf("identity = %#v, want validated claims", identity)
	}
}

func TestAuth0AuthenticatorRejectsMalformedOrUnvalidatedCredentials(t *testing.T) {
	tests := []struct {
		name   string
		header string
		claims any
		err    error
	}{
		{name: "missing header"},
		{name: "wrong scheme", header: "Basic abc"},
		{name: "empty bearer", header: "Bearer "},
		{name: "validator error", header: "Bearer invalid", err: errors.New("bad signature")},
		{name: "unexpected claims", header: "Bearer token", claims: map[string]any{"sub": "student"}},
		{name: "missing subject", header: "Bearer token", claims: &validator.ValidatedClaims{RegisteredClaims: validator.RegisteredClaims{Issuer: "issuer"}}},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			authenticator := &Auth0Authenticator{validator: stubTokenValidator{claims: test.claims, err: test.err}}
			request := httptest.NewRequest("GET", "/", nil)
			if test.header != "" {
				request.Header.Set("Authorization", test.header)
			}
			if _, err := authenticator.Authenticate(request); !errors.Is(err, ErrUnauthenticated) {
				t.Fatalf("Authenticate error = %v, want ErrUnauthenticated", err)
			}
		})
	}
}

type stubTokenValidator struct {
	claims any
	err    error
}

func (v stubTokenValidator) ValidateToken(context.Context, string) (any, error) {
	return v.claims, v.err
}

func signedJWT(t *testing.T, key *rsa.PrivateKey, claims map[string]any) string {
	t.Helper()
	header, _ := json.Marshal(map[string]string{"alg": "RS256", "kid": "test-key", "typ": "JWT"})
	payload, _ := json.Marshal(claims)
	unsigned := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	digest := crypto.SHA256.New()
	_, _ = digest.Write([]byte(unsigned))
	signature, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest.Sum(nil))
	if err != nil {
		t.Fatalf("sign JWT: %v", err)
	}
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(signature)
}

func encodeExponent(exponent int) string {
	return base64.RawURLEncoding.EncodeToString(big.NewInt(int64(exponent)).Bytes())
}
