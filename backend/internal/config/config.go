package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	AppEnv         string
	Port           string
	DatabaseURL    string
	JWTSecret      string
	JWTExpiry      time.Duration
	AllowedOrigins string
	FCMServerKey   string
	FCMProjectID   string
}

func LoadConfig() (*Config, error) {
	_ = godotenv.Load()

	port := getEnv("PORT", "8080")
	appEnv := getEnv("APP_ENV", "development")
	jwtSecret := getEnv("JWT_SECRET", "super-secret-songothon-jwt-key-change-in-production")
	allowedOrigins := getEnv("CORS_ALLOWED_ORIGINS", "*")
	fcmServerKey := getEnv("FCM_SERVER_KEY", "")
	fcmProjectID := getEnv("FCM_PROJECT_ID", "songothon-dev")

	expiryHoursStr := getEnv("JWT_EXPIRY_HOURS", "72")
	expiryHours, err := strconv.Atoi(expiryHoursStr)
	if err != nil {
		expiryHours = 72
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		dbHost := getEnv("DB_HOST", "localhost")
		dbPort := getEnv("DB_PORT", "5432")
		dbUser := getEnv("DB_USER", "postgres")
		dbPass := getEnv("DB_PASSWORD", "postgres")
		dbName := getEnv("DB_NAME", "songothon")
		dbSSL := getEnv("DB_SSLMODE", "disable")

		databaseURL = fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=%s",
			dbUser, dbPass, dbHost, dbPort, dbName, dbSSL)
	}

	return &Config{
		AppEnv:         appEnv,
		Port:           port,
		DatabaseURL:    databaseURL,
		JWTSecret:      jwtSecret,
		JWTExpiry:      time.Duration(expiryHours) * time.Hour,
		AllowedOrigins: allowedOrigins,
		FCMServerKey:   fcmServerKey,
		FCMProjectID:   fcmProjectID,
	}, nil
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}
