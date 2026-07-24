package accounts_test

import (
	"context"
	"path/filepath"
	"strings"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/crypto"
)

func TestStore_UpsertGetAndTeardown(t *testing.T) {
	t.Parallel()

	key := crypto.MustKeyFromHex("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
	path := filepath.Join(t.TempDir(), "accounts.json")
	store, err := accounts.Open(path, key)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}

	acct := accounts.Account{
		ID:             "https://accounts.google.com|sub-1",
		Email:          "work@example.com",
		Label:          "Work",
		RefreshToken:   "refresh-token-plain",
		SubscriptionID: "subscriptions/sub-1",
		NtfyTopic:      "secret-topic",
	}
	if err := store.Upsert(context.Background(), acct); err != nil {
		t.Fatalf("Upsert: %v", err)
	}

	got, ok := store.Get(acct.ID)
	if !ok {
		t.Fatal("expected account after upsert")
	}
	if got.RefreshToken != "refresh-token-plain" {
		t.Fatalf("RefreshToken = %q", got.RefreshToken)
	}
	if got.Email != "work@example.com" {
		t.Fatalf("Email = %q", got.Email)
	}

	raw, err := store.RawBytes()
	if err != nil {
		t.Fatalf("RawBytes: %v", err)
	}
	if strings.Contains(string(raw), "refresh-token-plain") {
		t.Fatal("plaintext refresh token found on disk")
	}

	var deletedSub, revokedToken, unboundTopic string
	teardown := accounts.TeardownHooks{
		DeleteSubscription: func(ctx context.Context, subscriptionID string) error {
			deletedSub = subscriptionID
			return nil
		},
		RevokeRefreshToken: func(ctx context.Context, refreshToken string) error {
			revokedToken = refreshToken
			return nil
		},
		InvalidateNtfyBinding: func(ctx context.Context, accountID, topic string) error {
			unboundTopic = topic
			return nil
		},
	}

	if err := store.Remove(context.Background(), acct.ID, teardown); err != nil {
		t.Fatalf("Remove: %v", err)
	}
	if deletedSub != "subscriptions/sub-1" {
		t.Fatalf("DeleteSubscription got %q", deletedSub)
	}
	if revokedToken != "refresh-token-plain" {
		t.Fatalf("RevokeRefreshToken got %q", revokedToken)
	}
	if unboundTopic != "secret-topic" {
		t.Fatalf("InvalidateNtfyBinding topic = %q", unboundTopic)
	}
	if _, ok := store.Get(acct.ID); ok {
		t.Fatal("account should be gone after teardown")
	}
}

func TestStore_RemoveMissingIsNoop(t *testing.T) {
	t.Parallel()

	key := crypto.MustKeyFromHex("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
	store, err := accounts.Open(filepath.Join(t.TempDir(), "a.json"), key)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	err = store.Remove(context.Background(), "missing", accounts.TeardownHooks{})
	if err != nil {
		t.Fatalf("Remove missing: %v", err)
	}
}
