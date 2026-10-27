package conn

import (
	"context"
	"fmt"
	"log"
	"log/slog"
	"net"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"songothon/config"
)

var db *pgxpool.Pool

func ConnectDB() {
	dbConf := config.DB().Db

	slog.Info("connecting to postgres",
		"host", dbConf.Host,
		"port", dbConf.Port,
		"dbname", dbConf.Name,
	)

	dsn := fmt.Sprintf("postgres://%s:%s@%s/%s?sslmode=%s",
		dbConf.Username, dbConf.Password, net.JoinHostPort(dbConf.Host, fmt.Sprintf("%d", dbConf.Port)), dbConf.Name, dbConf.SSLMode)

	poolConf, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		slog.Error("failed to parse postgres config", "error", err)
		log.Fatalf("Fatal: failed to parse postgres config: %v", err)
	}

	if dbConf.MaxOpenConn != 0 {
		poolConf.MaxConns = int32(dbConf.MaxOpenConn)
	}
	if dbConf.MaxIdleConn != 0 {
		poolConf.MinConns = int32(dbConf.MaxIdleConn)
	}
	if dbConf.MaxLifeTime != 0 {
		poolConf.MaxConnLifetime = time.Duration(dbConf.MaxLifeTime) * time.Second
	}

	// Retry while the database container is still starting up.
	var pool *pgxpool.Pool
	for attempt := 1; attempt <= 10; attempt++ {
		pool, err = pgxpool.NewWithConfig(context.Background(), poolConf)
		if err == nil {
			if err = pool.Ping(context.Background()); err == nil {
				break
			}
			pool.Close()
		}

		slog.Info("waiting for database connection", "attempt", attempt, "error", err)
		time.Sleep(2 * time.Second)
	}
	if err != nil {
		slog.Error("failed to connect to postgres database", "error", err)
		log.Fatalf("Fatal: failed to connect to postgres database: %v", err)
	}

	db = pool
	slog.Info("postgres connection successful...")
}

func Db() *pgxpool.Pool {
	return db
}

func Close() {
	if db != nil {
		db.Close()
	}
}
