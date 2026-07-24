package config

import (
	"fmt"
	"strconv"
	"strings"

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
	TokenEncryptionKey string
	PubSubVerifyToken  string
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

	if cfg.Env == "production" && cfg.NtfyTopic == "" {
		return Config{}, fmt.Errorf("NTFY_TOPIC is required in production")
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
