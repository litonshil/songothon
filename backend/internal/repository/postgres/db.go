package postgres

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"songothon/migrations"
)

type DB struct {
	Pool *pgxpool.Pool
}

func NewDB(ctx context.Context, databaseURL string) (*DB, error) {
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse database config: %w", err)
	}

	config.MaxConns = 25
	config.MinConns = 5
	config.MaxConnLifetime = 1 * time.Hour
	config.MaxConnIdleTime = 30 * time.Minute

	// Ping database with retry for Docker startup synchronization
	var pool *pgxpool.Pool
	for attempts := 1; attempts <= 10; attempts++ {
		pool, err = pgxpool.NewWithConfig(ctx, config)
		if err == nil {
			pingErr := pool.Ping(ctx)
			if pingErr == nil {
				log.Println("Connected to PostgreSQL successfully")
				break
			}
			err = pingErr
			pool.Close()
		}

		log.Printf("Waiting for database connection (attempt %d/10): %v\n", attempts, err)
		time.Sleep(2 * time.Second)
	}

	if err != nil {
		return nil, fmt.Errorf("unable to establish connection to database: %w", err)
	}

	db := &DB{Pool: pool}

	// Auto-run schema migrations
	if err := db.AutoMigrate(ctx); err != nil {
		return nil, fmt.Errorf("database schema migration failed: %w", err)
	}

	return db, nil
}

func (db *DB) AutoMigrate(ctx context.Context) error {
	log.Println("Applying database schema migrations...")
	if _, err := db.Pool.Exec(ctx, migrations.SchemaSQL); err != nil {
		return fmt.Errorf("failed to apply schema migrations: %w", err)
	}
	if _, err := db.Pool.Exec(ctx, migrations.RequirementsSQL); err != nil {
		return fmt.Errorf("failed to apply requirements migrations: %w", err)
	}
	if _, err := db.Pool.Exec(ctx, migrations.ExpensesSQL); err != nil {
		return fmt.Errorf("failed to apply expenses migrations: %w", err)
	}
	if _, err := db.Pool.Exec(ctx, migrations.IncomesSQL); err != nil {
		return fmt.Errorf("failed to apply incomes migrations: %w", err)
	}

	log.Println("Applying initial seed data if not present...")
	if _, err := db.Pool.Exec(ctx, migrations.SeedSQL); err != nil {
		log.Printf("Seed data notice (likely already seeded): %v\n", err)
	}

	log.Println("Database migration completed successfully.")
	return nil
}

func (db *DB) Close() {
	if db.Pool != nil {
		db.Pool.Close()
	}
}
