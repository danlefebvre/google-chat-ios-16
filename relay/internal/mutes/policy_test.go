package mutes_test

import (
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mutes"
)

func TestShouldNotify_DefaultAllows(t *testing.T) {
	t.Parallel()

	p := mutes.NewPolicy(nil, nil, mutes.QuietHours{})
	if !p.ShouldNotify("acct-1", "spaces/AAA", time.Date(2026, 7, 24, 15, 0, 0, 0, time.UTC)) {
		t.Fatal("expected notify allowed by default")
	}
}

func TestShouldNotify_MutedAccount(t *testing.T) {
	t.Parallel()

	p := mutes.NewPolicy(map[string]bool{"acct-1": true}, nil, mutes.QuietHours{})
	if p.ShouldNotify("acct-1", "spaces/AAA", time.Now().UTC()) {
		t.Fatal("muted account should not notify")
	}
	if !p.ShouldNotify("acct-2", "spaces/AAA", time.Now().UTC()) {
		t.Fatal("other account should notify")
	}
}

func TestShouldNotify_MutedSpace(t *testing.T) {
	t.Parallel()

	p := mutes.NewPolicy(nil, map[string]bool{"acct-1:spaces/AAA": true}, mutes.QuietHours{})
	if p.ShouldNotify("acct-1", "spaces/AAA", time.Now().UTC()) {
		t.Fatal("muted space should not notify")
	}
	if !p.ShouldNotify("acct-1", "spaces/BBB", time.Now().UTC()) {
		t.Fatal("unmuted space should notify")
	}
}

func TestShouldNotify_QuietHours(t *testing.T) {
	t.Parallel()

	loc := time.FixedZone("EST", -5*3600)
	qh := mutes.QuietHours{Enabled: true, StartHour: 22, EndHour: 7, Location: loc}
	p := mutes.NewPolicy(nil, nil, qh)

	during := time.Date(2026, 7, 24, 23, 30, 0, 0, loc)
	if p.ShouldNotify("acct-1", "spaces/AAA", during) {
		t.Fatal("quiet hours should suppress notify")
	}

	outside := time.Date(2026, 7, 24, 10, 0, 0, 0, loc)
	if !p.ShouldNotify("acct-1", "spaces/AAA", outside) {
		t.Fatal("outside quiet hours should notify")
	}
}

func TestSpaceKey(t *testing.T) {
	t.Parallel()
	if got := mutes.SpaceKey("a", "spaces/X"); got != "a:spaces/X" {
		t.Fatalf("SpaceKey = %q", got)
	}
}
