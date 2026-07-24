package mutes_test

import (
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mutes"
)

func TestShouldNotify_AllowsByDefault(t *testing.T) {
	rules := mutes.NewRules()
	ok := rules.ShouldNotify(mutes.Event{
		AccountID: "acc-1",
		SpaceName: "spaces/AAA",
		At:        time.Date(2026, 7, 24, 10, 0, 0, 0, time.UTC),
	})
	if !ok {
		t.Fatal("expected notify by default")
	}
}

func TestShouldNotify_RespectsAccountMute(t *testing.T) {
	rules := mutes.NewRules()
	rules.MuteAccount("acc-1")
	ok := rules.ShouldNotify(mutes.Event{
		AccountID: "acc-1",
		SpaceName: "spaces/AAA",
		At:        time.Date(2026, 7, 24, 10, 0, 0, 0, time.UTC),
	})
	if ok {
		t.Fatal("expected muted account to suppress notify")
	}
}

func TestShouldNotify_RespectsSpaceMute(t *testing.T) {
	rules := mutes.NewRules()
	rules.MuteSpace("acc-1", "spaces/AAA")
	ok := rules.ShouldNotify(mutes.Event{
		AccountID: "acc-1",
		SpaceName: "spaces/AAA",
		At:        time.Date(2026, 7, 24, 10, 0, 0, 0, time.UTC),
	})
	if ok {
		t.Fatal("expected muted space to suppress notify")
	}
}

func TestShouldNotify_RespectsQuietHours(t *testing.T) {
	loc := time.UTC
	rules := mutes.NewRules()
	rules.SetQuietHours(mutes.QuietHours{
		StartMinute: 22 * 60, // 22:00
		EndMinute:   7 * 60,  // 07:00
		Location:    loc,
	})

	during := rules.ShouldNotify(mutes.Event{
		AccountID: "acc-1",
		SpaceName: "spaces/AAA",
		At:        time.Date(2026, 7, 24, 23, 30, 0, 0, loc),
	})
	if during {
		t.Fatal("expected quiet hours to suppress notify")
	}

	outside := rules.ShouldNotify(mutes.Event{
		AccountID: "acc-1",
		SpaceName: "spaces/AAA",
		At:        time.Date(2026, 7, 24, 10, 0, 0, 0, loc),
	})
	if !outside {
		t.Fatal("expected notify outside quiet hours")
	}
}
