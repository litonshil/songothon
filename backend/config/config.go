package config

import (
	"errors"
	"log"

	"github.com/spf13/viper"
	_ "github.com/spf13/viper/remote"
)

var c Config

type Config struct {
	App *AppConfig
	Db  *DbClient
	FCM *FCMClient
}

type AppConfig struct {
	Name           string
	Port           int
	Env            string
	LogLevel       string `mapstructure:"log_level"`
	JWTSecret      string `mapstructure:"jwt_secret"`
	JWTExpiryHours int    `mapstructure:"jwt_expiry_hours"`
}

type DbClient struct {
	Db *DBConfig
}

type DBConfig struct {
	Host        string
	Port        int
	Name        string
	Username    string
	Password    string
	SSLMode     string `mapstructure:"ssl_mode"`
	MaxLifeTime int    `mapstructure:"max_life_time"` // seconds
	MaxIdleConn int    `mapstructure:"max_idle_conn"`
	MaxOpenConn int    `mapstructure:"max_open_conn"`
}

type FCMClient struct {
	FCM *FCMConfig
}

type FCMConfig struct {
	ServerKey string `mapstructure:"server_key"`
	ProjectID string `mapstructure:"project_id"`
}

func Get() Config {
	return c
}

func App() *AppConfig {
	return c.App
}

func DB() *DbClient {
	return c.Db
}

func FCM() *FCMClient {
	return c.FCM
}

func Load() error {
	setDefaultConfig()

	if err := bindEnvVariables(); err != nil {
		return err
	}

	consulURL := viper.GetString("CONSUL_URL")
	consulPath := viper.GetString("CONSUL_PATH")

	if consulURL == "" || consulPath == "" {
		return errors.New("CONSUL_URL and CONSUL_PATH must be set")
	}

	return loadConfigFromConsul(consulURL, consulPath)
}

func bindEnvVariables() error {
	envVars := []string{"CONSUL_URL", "CONSUL_PATH"}
	for _, v := range envVars {
		if err := viper.BindEnv(v); err != nil {
			log.Printf("Error binding env variable %s: %v", v, err)
			return err
		}
	}
	return nil
}

func loadConfigFromConsul(consulURL, consulPath string) error {
	viper.SetConfigType("json")
	if err := viper.AddRemoteProvider("consul", consulURL, consulPath); err != nil {
		log.Printf("Failed to add remote provider: %v", err)
		return err
	}
	if err := viper.ReadRemoteConfig(); err != nil {
		log.Printf("Failed to read remote config from Consul: %v", err)
		return err
	}
	log.Printf("Loaded configuration from Consul URL: %v, Path: %v", consulURL, consulPath)
	return unmarshalConfig()
}

func unmarshalConfig() error {
	c = Config{}
	if err := viper.Unmarshal(&c); err != nil {
		log.Printf("Unable to decode config: %v", err)
		return err
	}
	return nil
}

func setDefaultConfig() {
	viper.SetDefault("app.name", "songothon")
	viper.SetDefault("app.port", 8080)
	viper.SetDefault("app.env", "development")
	viper.SetDefault("app.log_level", "info")
	viper.SetDefault("app.jwt_secret", "super-secret-songothon-jwt-key-change-in-production")
	viper.SetDefault("app.jwt_expiry_hours", 72)

	viper.SetDefault("db.db.host", "localhost")
	viper.SetDefault("db.db.port", 5432)
	viper.SetDefault("db.db.name", "songothon_db")
	viper.SetDefault("db.db.username", "postgres")
	viper.SetDefault("db.db.password", "postgres")
	viper.SetDefault("db.db.ssl_mode", "disable")
	viper.SetDefault("db.db.max_life_time", 3600)
	viper.SetDefault("db.db.max_idle_conn", 5)
	viper.SetDefault("db.db.max_open_conn", 25)

	viper.SetDefault("fcm.fcm.server_key", "")
	viper.SetDefault("fcm.fcm.project_id", "songothon-dev")
}
