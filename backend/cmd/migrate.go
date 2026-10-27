package cmd

import (
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"

	"songothon/config"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/spf13/cobra"
)

var migrateCmd = &cobra.Command{
	Use:   "migrate",
	Short: "Database migration commands",
}

var migrateUpCmd = &cobra.Command{
	Use:   "up",
	Short: "Apply all up migrations",
	RunE: func(cmd *cobra.Command, args []string) error {
		return runMigration("up", -1)
	},
}

var migrateDownCmd = &cobra.Command{
	Use:   "down",
	Short: "Apply all down migrations",
	RunE: func(cmd *cobra.Command, args []string) error {
		return runMigration("down", -1)
	},
}

var migrateForceCmd = &cobra.Command{
	Use:   "force [version]",
	Short: "Force set migration version to fix dirty state",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		var version int
		_, err := fmt.Sscanf(args[0], "%d", &version)
		if err != nil {
			return fmt.Errorf("invalid version format: %w", err)
		}
		return runMigration("force", version)
	},
}

func RegisterMigrateCommand() {
	migrateCmd.AddCommand(migrateUpCmd)
	migrateCmd.AddCommand(migrateDownCmd)
	migrateCmd.AddCommand(migrateForceCmd)
	RegisterSubCommand(migrateCmd)
}

func runMigration(direction string, version int) error {
	dbCfg := config.DB().Db
	if dbCfg == nil {
		return fmt.Errorf("DB config not loaded")
	}

	hostPort := net.JoinHostPort(dbCfg.Host, fmt.Sprintf("%d", dbCfg.Port))
	dsn := fmt.Sprintf("postgres://%s:%s@%s/%s?sslmode=%s",
		dbCfg.Username, dbCfg.Password, hostPort, dbCfg.Name, dbCfg.SSLMode)

	var migrationsDir string
	candidateDirs := []string{
		filepath.Join("..", "migrations"),
		filepath.Join(".", "migrations"),
	}
	found := false
	for _, dir := range candidateDirs {
		if fi, err := os.Stat(dir); err == nil && fi.IsDir() {
			migrationsDir = "file://" + dir
			found = true
			fmt.Printf("Migrations directory: %s\n", migrationsDir)
			break
		}
	}
	if !found {
		return fmt.Errorf("no migrations directory found in any of: %v", candidateDirs)
	}

	m, err := migrate.New(migrationsDir, dsn)
	if err != nil {
		return fmt.Errorf("failed to create migrate instance: %w", err)
	}
	defer func(m *migrate.Migrate) {
		err, _ := m.Close()
		if err != nil {
			fmt.Printf("Failed to close migrate instance: %v\n", err)
		}
	}(m)

	switch direction {
	case "up":
		fmt.Println("Applying all up migrations...")
		err = m.Up()
		if err != nil && !errors.Is(err, migrate.ErrNoChange) {
			return fmt.Errorf("migration up failed: %w", err)
		}
		fmt.Println("Migration up completed successfully.")
	case "down":
		fmt.Println("Applying all down migrations...")
		err = m.Down()
		if err != nil && !errors.Is(err, migrate.ErrNoChange) {
			return fmt.Errorf("migration down failed: %w", err)
		}
		fmt.Println("Migration down completed successfully.")
	case "force":
		fmt.Printf("Forcing migration version to %d...\n", version)
		err = m.Force(version)
		if err != nil {
			return fmt.Errorf("migration force failed: %w", err)
		}
		fmt.Println("Migration forced successfully.")
	default:
		return fmt.Errorf("invalid direction: %s", direction)
	}

	return nil
}
