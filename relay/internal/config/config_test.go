package config_test

import (
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/config"
)

func TestLoad_FromEnv(t *testing.T) {
	t.Setenv("PORT", "9090")
	t.Setenv("NTFY_BASE_URL", "https://ntfy.sh")
	t.Setenv("NTFY_TOPIC", "my-secret-topic")
	t.Setenv("NTFY_TOKEN", "tok")
	t.Setenv("TOKEN_ENCRYPTION_KEY", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
	t.Setenv("ACCOUNTS_PATH", "/tmp/accounts.json")
	t.Setenv("QUIET_HOURS_ENABLED", "true")
	t.Setenv("QUIET_HOURS_START", "22")
	t.Setenv("QUIET_HOURS_END", "7")
	t.Setenv("QUIET_HOURS_TZ", "America/New_York")

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.Port != "9090" {
		t.Fatalf("Port = %q", cfg.Port)
	}
	if cfg.NtfyBaseURL != "https://ntfy.sh" {
		t.Fatalf("NtfyBaseURL = %q", cfg.NtfyBaseURL)
	}
	if cfg.NtfyTopic != "my-secret-topic" {
		t.Fatalf("NtfyTopic = %q", cfg.NtfyTopic)
	}
	if !cfg.QuietHours.Enabled {
		t.Fatal("QuietHours should be enabled")
	}
	if cfg.QuietHours.StartHour != 22 || cfg.QuietHours.EndHour != 7 {
		t.Fatalf("quiet hours = %d-%d", cfg.QuietHours.StartHour, cfg.QuietHours.EndHour)
	}
}

func TestLoad_RequiresTopicAndKey(t *testing.T) {
	t.Setenv("PORT", "8080")
	t.Setenv("NTFY_BASE_URL", "https://ntfy.sh")
	t.Setenv("NTFY_TOPIC", "")
	t.Setenv("TOKEN_ENCRYPTION_KEY", "")
	t.Setenv("ACCOUNTS_PATH", "")

	if _, err := config.Load(); err == nil {
		t.Fatal("expected error when required env missing")
	}
}
