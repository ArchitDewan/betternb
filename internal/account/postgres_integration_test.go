package account

import (
	"context"
	"fmt"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestPostgresStoreConcurrentBootstrapIsIdempotent(t *testing.T) {
	databaseURL := os.Getenv("BETTERNB_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("BETTERNB_TEST_DATABASE_URL is not set")
	}
	ctx := context.Background()
	adminPool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	defer adminPool.Close()
	schema := fmt.Sprintf("betternb_account_test_%d", time.Now().UnixNano())
	quotedSchema := pgx.Identifier{schema}.Sanitize()
	if _, err := adminPool.Exec(ctx, `CREATE SCHEMA `+quotedSchema); err != nil {
		t.Fatalf("create isolated test schema: %v", err)
	}
	defer func() {
		if _, err := adminPool.Exec(ctx, `DROP SCHEMA `+quotedSchema+` CASCADE`); err != nil {
			t.Errorf("drop isolated test schema: %v", err)
		}
	}()

	poolConfig, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		t.Fatalf("parse test database configuration: %v", err)
	}
	poolConfig.AfterConnect = func(ctx context.Context, connection *pgx.Conn) error {
		_, err := connection.Exec(ctx, `SET search_path TO `+quotedSchema)
		return err
	}
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		t.Fatalf("connect isolated pool: %v", err)
	}
	defer pool.Close()
	if err := ApplyMigrations(ctx, pool); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	store := NewPostgresStore(pool)
	identity := Identity{Issuer: "https://integration.auth0.com/", Subject: "apple|same-student"}
	const attempts = 8
	accounts := make(chan Account, attempts)
	created := make(chan bool, attempts)
	errorsFound := make(chan error, attempts)
	var group sync.WaitGroup
	for range attempts {
		group.Add(1)
		go func() {
			defer group.Done()
			account, wasCreated, err := store.FindOrCreate(ctx, identity)
			if err != nil {
				errorsFound <- err
				return
			}
			accounts <- account
			created <- wasCreated
		}()
	}
	group.Wait()
	close(accounts)
	close(created)
	close(errorsFound)
	for err := range errorsFound {
		t.Errorf("FindOrCreate: %v", err)
	}

	var accountID string
	for account := range accounts {
		if accountID == "" {
			accountID = account.ID
		}
		if account.ID != accountID {
			t.Errorf("account ID = %q, want stable %q", account.ID, accountID)
		}
	}
	createdCount := 0
	for wasCreated := range created {
		if wasCreated {
			createdCount++
		}
	}
	if createdCount != 1 {
		t.Errorf("created count = %d, want 1", createdCount)
	}

	found, err := store.Find(ctx, identity)
	if err != nil {
		t.Fatalf("Find: %v", err)
	}
	if found.ID != accountID {
		t.Errorf("Find account ID = %q, want %q", found.ID, accountID)
	}
}
