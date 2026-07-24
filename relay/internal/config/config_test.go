package config_test

import (
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/config"
)

func TestLoad_Defaults(t *testing.T) {
	t.Parallel()
	cfg, err := config.Load(map[string]string{})
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.HTTPAddr != ":8080" {
		t.Fatalf("HTTPAddr = %q", cfg.HTTPAddr)
	}
	if cfg.NtfyBaseURL != "https://ntfy.sh" {
		t.Fatalf("NtfyBaseURL = %q", cfg.NtfyBaseURL)
	}
}

func TestLoad_RequiresTopicInProductionMode(t *testing.T) {
	t.Parallel()
	_, err := config.Load(map[string]string{
		"RELAY_ENV": "production",
	})
	if err == nil {
		t.Fatal("expected error when NTFY_TOPIC missing in production")
	}
}

func TestLoad_ReadsSecrets(t *testing.T) {
	t.Parallel()
	cfg, err := config.Load(map[string]string{
		"HTTP_ADDR":            ":9090",
		"NTFY_BASE_URL":        "https://ntfy.sh",
		"NTFY_TOPIC":           "hard-to-guess-topic",
		"NTFY_ACCESS_TOKEN":    "tok",
		"QUIET_HOURS_START":    "22",
		"QUIET_HOURS_END":      "7",
		"TOKEN_ENCRYPTION_KEY": "0123456789abcdef0123456789abcdef",
	})
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.NtfyTopic != "hard-to-guess-topic" {
		t.Fatalf("topic = %q", cfg.NtfyTopic)
	}
	if cfg.QuietHours.Start != 22 || cfg.QuietHours.End != 7 {
		t.Fatalf("quiet = %+v", cfg.QuietHours)
	}
	if cfg.NtfyAccessToken != "tok" {
		t.Fatalf("token = %q", cfg.NtfyAccessToken)
	}
}
