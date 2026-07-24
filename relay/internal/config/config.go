package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/crypto"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mutes"
)

// Config is runtime configuration for the ntfy relay.
type Config struct {
	Port            string
	NtfyBaseURL     string
	NtfyTopic       string
	NtfyToken       string
	AccountsPath    string
	EncryptionKey   []byte
	QuietHours      mutes.QuietHours
	ClickScheme     string
	GoogleClientID  string
	GoogleClientSec string
}

// Load reads configuration from environment variables.
func Load() (Config, error) {
	topic := os.Getenv("NTFY_TOPIC")
	keyHex := os.Getenv("TOKEN_ENCRYPTION_KEY")
	if topic == "" || keyHex == "" {
		return Config{}, fmt.Errorf("NTFY_TOPIC and TOKEN_ENCRYPTION_KEY are required")
	}
	key, err := crypto.KeyFromHex(keyHex)
	if err != nil {
		return Config{}, err
	}

	port := envOr("PORT", "8080")
	base := envOr("NTFY_BASE_URL", "https://ntfy.sh")
	accountsPath := envOr("ACCOUNTS_PATH", "./data/accounts.json")
	qhEnabled := envBool("QUIET_HOURS_ENABLED", false)
	start := envInt("QUIET_HOURS_START", 22)
	end := envInt("QUIET_HOURS_END", 7)
	tzName := envOr("QUIET_HOURS_TZ", "UTC")
	loc, err := time.LoadLocation(tzName)
	if err != nil {
		return Config{}, fmt.Errorf("QUIET_HOURS_TZ: %w", err)
	}

	return Config{
		Port:            port,
		NtfyBaseURL:     base,
		NtfyTopic:       topic,
		NtfyToken:       os.Getenv("NTFY_TOKEN"),
		AccountsPath:    accountsPath,
		EncryptionKey:   key,
		ClickScheme:     envOr("CLICK_SCHEME", "googlechatmulti"),
		GoogleClientID:  os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleClientSec: os.Getenv("GOOGLE_CLIENT_SECRET"),
		QuietHours: mutes.QuietHours{
			Enabled:   qhEnabled,
			StartHour: start,
			EndHour:   end,
			Location:  loc,
		},
	}, nil
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envBool(key string, fallback bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return fallback
	}
	return b
}

func envInt(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}
