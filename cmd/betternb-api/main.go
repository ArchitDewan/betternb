package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ArchitDewan/betternb/internal/account"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	address := flag.String("address", "127.0.0.1:8081", "HTTP listen address")
	migrate := flag.Bool("migrate", false, "apply pending database migrations before serving")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))
	if err := run(*address, *migrate, logger); err != nil {
		logger.Error("account API stopped", "error", err)
		os.Exit(1)
	}
}

func run(address string, migrate bool, logger *slog.Logger) error {
	databaseURL := os.Getenv("BETTERNB_DATABASE_URL")
	issuer := os.Getenv("BETTERNB_AUTH0_ISSUER")
	audience := os.Getenv("BETTERNB_AUTH0_AUDIENCE")
	if databaseURL == "" || issuer == "" || audience == "" {
		return errors.New("BETTERNB_DATABASE_URL, BETTERNB_AUTH0_ISSUER, and BETTERNB_AUTH0_AUDIENCE are required")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()
	if err := pool.Ping(ctx); err != nil {
		return err
	}
	if migrate {
		if err := account.ApplyMigrations(ctx, pool); err != nil {
			return err
		}
	}
	authenticator, err := account.NewAuth0Authenticator(issuer, audience)
	if err != nil {
		return err
	}

	server := &http.Server{
		Addr:              address,
		Handler:           account.NewHandler(account.Config{Store: account.NewPostgresStore(pool), Authenticator: authenticator, Logger: logger}),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    32 << 10,
	}
	errChannel := make(chan error, 1)
	go func() {
		logger.Info("BetterNB account API is ready", "address", address)
		errChannel <- server.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownContext, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return server.Shutdown(shutdownContext)
	case err := <-errChannel:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}
