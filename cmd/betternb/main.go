package main

import (
	"flag"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/ArchitDewan/betternb/internal/web"
)

func main() {
	address := flag.String("address", "127.0.0.1:8080", "HTTP listen address")
	dataDir := flag.String("data-dir", "./var/betternb", "directory for development data")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))
	app, err := web.New(web.Config{DataDir: *dataDir, Logger: logger})
	if err != nil {
		logger.Error("initialize application", "error", err)
		os.Exit(1)
	}

	server := &http.Server{
		Addr:              *address,
		Handler:           app.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	logger.Info("BetterNB is ready", "url", "http://"+*address, "data_dir", *dataDir)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Error("server stopped", "error", err)
		os.Exit(1)
	}
}
