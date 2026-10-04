package account

import (
	"context"
	"embed"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) FindOrCreate(ctx context.Context, identity Identity) (Account, bool, error) {
	if !identity.Valid() {
		return Account{}, false, errors.New("valid identity is required")
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return Account{}, false, fmt.Errorf("begin account transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Serialize bootstrap for one identity without blocking unrelated students.
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))`, identity.Issuer, identity.Subject); err != nil {
		return Account{}, false, fmt.Errorf("lock identity: %w", err)
	}
	account, err := findAccount(ctx, tx, identity)
	if err == nil {
		if _, err := tx.Exec(ctx, `UPDATE auth_identities SET last_seen_at = CURRENT_TIMESTAMP WHERE issuer = $1 AND subject = $2`, identity.Issuer, identity.Subject); err != nil {
			return Account{}, false, fmt.Errorf("update identity activity: %w", err)
		}
		if err := tx.Commit(ctx); err != nil {
			return Account{}, false, fmt.Errorf("commit account lookup: %w", err)
		}
		return account, false, nil
	}
	if !errors.Is(err, ErrAccountNotFound) {
		return Account{}, false, err
	}

	if err := tx.QueryRow(ctx, `INSERT INTO accounts DEFAULT VALUES RETURNING id, status, created_at`).Scan(&account.ID, &account.Status, &account.CreatedAt); err != nil {
		return Account{}, false, fmt.Errorf("create account: %w", err)
	}
	if _, err := tx.Exec(ctx, `INSERT INTO auth_identities (issuer, subject, account_id) VALUES ($1, $2, $3)`, identity.Issuer, identity.Subject, account.ID); err != nil {
		return Account{}, false, fmt.Errorf("create auth identity: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return Account{}, false, fmt.Errorf("commit account creation: %w", err)
	}
	return account, true, nil
}

func (s *PostgresStore) Find(ctx context.Context, identity Identity) (Account, error) {
	return findAccount(ctx, s.pool, identity)
}

type rowQuerier interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}

func findAccount(ctx context.Context, db rowQuerier, identity Identity) (Account, error) {
	var account Account
	err := db.QueryRow(ctx, `
		SELECT accounts.id, accounts.status, accounts.created_at
		FROM accounts
		JOIN auth_identities ON auth_identities.account_id = accounts.id
		WHERE auth_identities.issuer = $1 AND auth_identities.subject = $2
	`, identity.Issuer, identity.Subject).Scan(&account.ID, &account.Status, &account.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Account{}, ErrAccountNotFound
	}
	if err != nil {
		return Account{}, fmt.Errorf("find account: %w", err)
	}
	return account, nil
}

func ApplyMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	if _, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			name TEXT PRIMARY KEY,
			applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
		)
	`); err != nil {
		return fmt.Errorf("create migration ledger: %w", err)
	}
	entries, err := fs.ReadDir(migrationFiles, "migrations")
	if err != nil {
		return fmt.Errorf("list migrations: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if err := applyMigration(ctx, pool, entry.Name()); err != nil {
			return err
		}
	}
	return nil
}

func applyMigration(ctx context.Context, pool *pgxpool.Pool, name string) error {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin migration %s: %w", name, err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext('betternb-schema-migration'), hashtext($1))`, name); err != nil {
		return fmt.Errorf("lock migration %s: %w", name, err)
	}
	var appliedAt time.Time
	err = tx.QueryRow(ctx, `SELECT applied_at FROM schema_migrations WHERE name = $1`, name).Scan(&appliedAt)
	if err == nil {
		return tx.Commit(ctx)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("check migration %s: %w", name, err)
	}
	contents, err := migrationFiles.ReadFile("migrations/" + name)
	if err != nil {
		return fmt.Errorf("read migration %s: %w", name, err)
	}
	if _, err := tx.Exec(ctx, string(contents)); err != nil {
		return fmt.Errorf("apply migration %s: %w", name, err)
	}
	if _, err := tx.Exec(ctx, `INSERT INTO schema_migrations (name) VALUES ($1)`, name); err != nil {
		return fmt.Errorf("record migration %s: %w", name, err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit migration %s: %w", name, err)
	}
	return nil
}
