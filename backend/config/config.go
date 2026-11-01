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
	FCM *FCMServiceAccount
}

// FCMServiceAccount holds the Firebase service-account key fields
// (Project settings -> Service accounts -> Generate new private key).
type FCMServiceAccount struct {
	Type                    string `mapstructure:"type" json:"type"`
	ProjectID               string `mapstructure:"project_id" json:"project_id"`
	PrivateKeyID            string `mapstructure:"private_key_id" json:"private_key_id"`
	PrivateKey              string `mapstructure:"private_key" json:"private_key"`
	ClientEmail             string `mapstructure:"client_email" json:"client_email"`
	ClientID                string `mapstructure:"client_id" json:"client_id"`
	AuthURI                 string `mapstructure:"auth_uri" json:"auth_uri"`
	TokenURI                string `mapstructure:"token_uri" json:"token_uri"`
	AuthProviderX509CertURL string `mapstructure:"auth_provider_x509_cert_url" json:"auth_provider_x509_cert_url"`
	ClientX509CertURL       string `mapstructure:"client_x509_cert_url" json:"client_x509_cert_url"`
	UniverseDomain          string `mapstructure:"universe_domain" json:"universe_domain"`
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

	viper.SetDefault("fcm.fcm.type", "service_account")
	viper.SetDefault("fcm.fcm.project_id", "")
	viper.SetDefault("fcm.fcm.private_key", "")
	viper.SetDefault("fcm.fcm.token_uri", "https://oauth2.googleapis.com/token")
}
