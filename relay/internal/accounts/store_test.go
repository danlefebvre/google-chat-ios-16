package accounts_test

import (
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
)

func TestStore_UpsertAndGet(t *testing.T) {
	store := accounts.NewMemoryStore()
	acc := accounts.Account{
		ID:           "issuer|sub-1",
		Email:        "work@example.com",
		Label:        "Work",
		RefreshToken: "rt-1",
		Subscription: "subscriptions/sub-1",
		NtfyTopic:    "secret-topic",
	}
	if err := store.Upsert(acc); err != nil {
		t.Fatalf("Upsert: %v", err)
	}
	got, ok := store.Get("issuer|sub-1")
	if !ok {
		t.Fatal("expected account")
	}
	if got.RefreshToken != "rt-1" || got.Label != "Work" {
		t.Fatalf("got %+v", got)
	}
}

func TestStore_TeardownDeletesSubscriptionTokenAndBinding(t *testing.T) {
	subs := &fakeSubscriptions{}
	tokens := &fakeTokens{tokens: map[string]string{"issuer|sub-1": "rt-1"}}
	store := accounts.NewMemoryStore()
	_ = store.Upsert(accounts.Account{
		ID:           "issuer|sub-1",
		Label:        "Work",
		RefreshToken: "rt-1",
		Subscription: "subscriptions/sub-1",
		NtfyTopic:    "secret-topic",
	})

	err := accounts.Teardown(store, subs, tokens, "issuer|sub-1")
	if err != nil {
		t.Fatalf("Teardown: %v", err)
	}
	if !subs.deleted["subscriptions/sub-1"] {
		t.Fatal("expected Workspace Events subscription deleted first")
	}
	if _, ok := tokens.tokens["issuer|sub-1"]; ok {
		t.Fatal("expected refresh token revoked/deleted")
	}
	if _, ok := store.Get("issuer|sub-1"); ok {
		t.Fatal("expected account binding removed from store")
	}
	if len(subs.order) == 0 || subs.order[0] != "delete-sub" {
		t.Fatalf("teardown order = %v, want delete-sub first", subs.order)
	}
}

type fakeSubscriptions struct {
	deleted map[string]bool
	order   []string
}

func (f *fakeSubscriptions) DeleteSubscription(name string) error {
	if f.deleted == nil {
		f.deleted = map[string]bool{}
	}
	f.deleted[name] = true
	f.order = append(f.order, "delete-sub")
	return nil
}

type fakeTokens struct {
	tokens map[string]string
	order  []string
}

func (f *fakeTokens) Revoke(accountID string) error {
	delete(f.tokens, accountID)
	f.order = append(f.order, "revoke-token")
	return nil
}
