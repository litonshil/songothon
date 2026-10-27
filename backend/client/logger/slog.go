package logger

import (
	"log/slog"
	"os"

	"songothon/config"
)

var logger *slog.Logger

func Set(config config.AppConfig) {
	logger = slog.New(
		slog.NewJSONHandler(os.Stderr, nil),
	)

	slog.SetDefault(logger)
}

func Info(msg string, args ...any) {
	slog.Info(msg, args...)
}

func Error(msg string, args ...any) {
	slog.Error(msg, args...)
}
