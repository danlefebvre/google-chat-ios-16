package mute_test

import (
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mute"
)

func TestShouldNotify_DefaultAllows(t *testing.T) {
	t.Parallel()
	s := mute.NewStore()
	if !s.ShouldNotify("acct1", "spaces/AAA") {
		t.Fatal("expected allow by default")
	}
}

func TestShouldNotify_AccountMuteBlocks(t *testing.T) {
	t.Parallel()
	s := mute.NewStore()
	s.MuteAccount("acct1")
	if s.ShouldNotify("acct1", "spaces/AAA") {
		t.Fatal("expected account mute to block")
	}
	if !s.ShouldNotify("acct2", "spaces/AAA") {
		t.Fatal("other account should still notify")
	}
}

func TestShouldNotify_SpaceMuteBlocks(t *testing.T) {
	t.Parallel()
	s := mute.NewStore()
	s.MuteSpace("acct1", "spaces/AAA")
	if s.ShouldNotify("acct1", "spaces/AAA") {
		t.Fatal("expected space mute to block")
	}
	if !s.ShouldNotify("acct1", "spaces/BBB") {
		t.Fatal("other space should notify")
	}
}

func TestUnmuteRestores(t *testing.T) {
	t.Parallel()
	s := mute.NewStore()
	s.MuteAccount("acct1")
	s.MuteSpace("acct1", "spaces/AAA")
	s.UnmuteAccount("acct1")
	s.UnmuteSpace("acct1", "spaces/AAA")
	if !s.ShouldNotify("acct1", "spaces/AAA") {
		t.Fatal("expected unmute to restore notifications")
	}
}
