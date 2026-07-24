package config

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/quiet"
)

// Config holds relay runtime settings.
type Config struct {
	HTTPAddr           string
	Env                string
	NtfyBaseURL        string
	NtfyTopic          string
	NtfyAccessToken    string
	QuietHours         quiet.Hours
	QuietHoursLocation *time.Location
	TokenEncryptionKey string
	PubSubVerifyToken  string
	APIToken           string
	GoogleClientID     string
	GoogleClientSecret string
	EventsBaseURL      string
}

// Load reads config from an env-like map (os.Environ style values by key).
func Load(env map[string]string) (Config, error) {
	get := func(k, def string) string {
		if v, ok := env[k]; ok && v != "" {
			return v
		}
		return def
	}
	cfg := Config{
		HTTPAddr:           get("HTTP_ADDR", ":8080"),
		Env:                strings.ToLower(get("RELAY_ENV", "development")),
		NtfyBaseURL:        get("NTFY_BASE_URL", "https://ntfy.sh"),
		NtfyTopic:          get("NTFY_TOPIC", ""),
		NtfyAccessToken:    get("NTFY_ACCESS_TOKEN", ""),
		TokenEncryptionKey: get("TOKEN_ENCRYPTION_KEY", ""),
		PubSubVerifyToken:  get("PUBSUB_VERIFY_TOKEN", ""),
		APIToken:           get("RELAY_API_TOKEN", ""),
		GoogleClientID:     get("GOOGLE_CLIENT_ID", ""),
		GoogleClientSecret: get("GOOGLE_CLIENT_SECRET", ""),
		EventsBaseURL:      get("WORKSPACE_EVENTS_BASE_URL", "https://workspaceevents.googleapis.com"),
	}
	start, err := atoiDefault(get("QUIET_HOURS_START", "0"), 0)
	if err != nil {
		return Config{}, err
	}
	end, err := atoiDefault(get("QUIET_HOURS_END", "0"), 0)
	if err != nil {
		return Config{}, err
	}
	cfg.QuietHours = quiet.Hours{Start: start, End: end}

	tzName := get("QUIET_HOURS_TZ", "UTC")
	loc, err := time.LoadLocation(tzName)
	if err != nil {
		return Config{}, fmt.Errorf("QUIET_HOURS_TZ: %w", err)
	}
	cfg.QuietHoursLocation = loc

	if cfg.Env == "production" && cfg.NtfyTopic == "" {
		return Config{}, fmt.Errorf("NTFY_TOPIC is required in production")
	}
	if cfg.Env == "production" && cfg.APIToken == "" {
		return Config{}, fmt.Errorf("RELAY_API_TOKEN is required in production")
	}
	return cfg, nil
}

func atoiDefault(s string, def int) (int, error) {
	if s == "" {
		return def, nil
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return 0, fmt.Errorf("invalid int %q: %w", s, err)
	}
	return n, nil
}
