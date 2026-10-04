package account

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/auth0/go-jwt-middleware/v3/jwks"
	"github.com/auth0/go-jwt-middleware/v3/validator"
)

type tokenValidator interface {
	ValidateToken(context.Context, string) (any, error)
}

// Auth0Authenticator validates Auth0 API access tokens and exposes only the
// stable OIDC identity needed by the account layer.
type Auth0Authenticator struct {
	validator tokenValidator
}

func NewAuth0Authenticator(issuer, audience string) (*Auth0Authenticator, error) {
	return newAuth0Authenticator(issuer, audience, nil)
}

func newAuth0Authenticator(issuer, audience string, httpClient *http.Client) (*Auth0Authenticator, error) {
	issuer = strings.TrimSpace(issuer)
	audience = strings.TrimSpace(audience)
	issuerURL, err := url.Parse(issuer)
	if err != nil || issuerURL.Scheme != "https" || issuerURL.Host == "" || issuerURL.User != nil || issuerURL.RawQuery != "" || issuerURL.Fragment != "" {
		return nil, errors.New("Auth0 issuer must be an absolute HTTPS URL")
	}
	if !strings.HasSuffix(issuerURL.Path, "/") {
		issuerURL.Path += "/"
	}
	if audience == "" {
		return nil, errors.New("Auth0 audience is required")
	}

	providerOptions := []any{
		jwks.WithIssuerURL(issuerURL),
		jwks.WithCacheTTL(15 * time.Minute),
		jwks.WithStrictJWKSURIOrigin(),
	}
	if httpClient != nil {
		providerOptions = append(providerOptions, jwks.WithCustomClient(httpClient))
	}
	provider, err := jwks.NewCachingProvider(providerOptions...)
	if err != nil {
		return nil, fmt.Errorf("configure Auth0 JWKS: %w", err)
	}
	tokenValidator, err := validator.New(
		validator.WithKeyFunc(provider.KeyFunc),
		validator.WithAlgorithm(validator.RS256),
		validator.WithIssuer(issuerURL.String()),
		validator.WithAudience(audience),
		validator.WithAllowedClockSkew(30*time.Second),
	)
	if err != nil {
		return nil, fmt.Errorf("configure Auth0 token validator: %w", err)
	}
	return &Auth0Authenticator{validator: tokenValidator}, nil
}

func (a *Auth0Authenticator) Authenticate(request *http.Request) (Identity, error) {
	parts := strings.Fields(request.Header.Get("Authorization"))
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || parts[1] == "" {
		return Identity{}, ErrUnauthenticated
	}
	validated, err := a.validator.ValidateToken(request.Context(), parts[1])
	if err != nil {
		return Identity{}, ErrUnauthenticated
	}
	claims, ok := validated.(*validator.ValidatedClaims)
	if !ok {
		return Identity{}, ErrUnauthenticated
	}
	identity := Identity{
		Issuer:  claims.RegisteredClaims.Issuer,
		Subject: claims.RegisteredClaims.Subject,
	}
	if !identity.Valid() {
		return Identity{}, ErrUnauthenticated
	}
	return identity, nil
}
