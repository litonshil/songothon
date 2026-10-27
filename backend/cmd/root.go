package cmd

import (
	"fmt"
	"os"

	"songothon/client/conn"
	"songothon/client/logger"
	"songothon/config"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "songothon",
	Short: "songothon service entrypoint",
}

func RegisterSubCommand(cmd *cobra.Command) {
	rootCmd.AddCommand(cmd)
}

func Execute() error {
	RegisterServeCommand()
	RegisterMigrateCommand()

	if err := config.Load(); err != nil {
		fmt.Fprintf(os.Stderr, "failed to load config: %v\n", err)
		os.Exit(1)
	}

	appConfig := config.App()
	logger.Set(*appConfig)

	conn.ConnectDB()
	defer conn.Close()

	return rootCmd.Execute()
}
