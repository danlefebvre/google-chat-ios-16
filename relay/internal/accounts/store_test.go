package accounts_test

import (
	"context"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
)

func TestStore_UpsertAndGet(t *testing.T) {
	t.Parallel()
	s := accounts.NewMemoryStore()
	acc := accounts.Account{
		ID:           "iss|sub1",
		Email:        "work@example.com",
		Label:        "Work",
		RefreshToken: "rt-1",
		NtfyBound:   true,
	}
	if err := s.Upsert(context.Background(), acc); err != nil {
		t.Fatalf("Upsert: %v", err)
	}
	got, ok := s.Get(context.Background(), "iss|sub1")
	if !ok {
		t.Fatal("expected account")
	}
	if got.Email != "work@example.com" || got.RefreshToken != "rt-1" {
		t.Fatalf("got %+v", got)
	}
}

func TestStore_List(t *testing.T) {
	t.Parallel()
	s := accounts.NewMemoryStore()
	_ = s.Upsert(context.Background(), accounts.Account{ID: "a", Label: "A"})
	_ = s.Upsert(context.Background(), accounts.Account{ID: "b", Label: "B"})
	list := s.List(context.Background())
	if len(list) != 2 {
		t.Fatalf("len = %d", len(list))
	}
}

func TestTeardown_DeletesSubscriptionRevokesTokenClearsBinding(t *testing.T) {
	t.Parallel()

	store := accounts.NewMemoryStore()
	_ = store.Upsert(context.Background(), accounts.Account{
		ID:               "iss|sub1",
		RefreshToken:     "rt-secret",
		SubscriptionName: "subscriptions/sub-1",
		NtfyBound:       true,
	})

	var deletedSub, revokedToken string
	var bindingCleared bool

	teardown := accounts.Teardown{
		Store: store,
		DeleteSubscription: func(ctx context.Context, name string) error {
			deletedSub = name
			return nil
		},
		RevokeRefreshToken: func(ctx context.Context, token string) error {
			revokedToken = token
			return nil
		},
		ClearNtfyBinding: func(ctx context.Context, accountID string) error {
			bindingCleared = true
			return nil
		},
	}

	if err := teardown.RemoveAccount(context.Background(), "iss|sub1"); err != nil {
		t.Fatalf("RemoveAccount: %v", err)
	}

	if deletedSub != "subscriptions/sub-1" {
		t.Fatalf("deletedSub = %q", deletedSub)
	}
	if revokedToken != "rt-secret" {
		t.Fatalf("revokedToken = %q", revokedToken)
	}
	if !bindingCleared {
		t.Fatal("expected ntfy binding cleared")
	}
	if _, ok := store.Get(context.Background(), "iss|sub1"); ok {
		t.Fatal("account should be removed from store")
	}
}

func TestTeardown_OrderIsSubscriptionThenTokenThenBindingThenStore(t *testing.T) {
	t.Parallel()

	var order []string
	store := &orderStore{
		inner: accounts.NewMemoryStore(),
		onDelete: func(id string) {
			order = append(order, "store")
		},
	}
	_ = store.Upsert(context.Background(), accounts.Account{
		ID:               "a1",
		RefreshToken:     "rt",
		SubscriptionName: "subs/1",
		NtfyBound:       true,
	})

	teardown := accounts.Teardown{
		Store: store,
		DeleteSubscription: func(ctx context.Context, name string) error {
			order = append(order, "subscription")
			return nil
		},
		RevokeRefreshToken: func(ctx context.Context, token string) error {
			order = append(order, "token")
			return nil
		},
		ClearNtfyBinding: func(ctx context.Context, accountID string) error {
			order = append(order, "binding")
			return nil
		},
	}
	if err := teardown.RemoveAccount(context.Background(), "a1"); err != nil {
		t.Fatalf("RemoveAccount: %v", err)
	}
	want := []string{"subscription", "token", "binding", "store"}
	if len(order) != len(want) {
		t.Fatalf("order = %v", order)
	}
	for i := range want {
		if order[i] != want[i] {
			t.Fatalf("order = %v, want %v", order, want)
		}
	}
}

type orderStore struct {
	inner    *accounts.MemoryStore
	onDelete func(id string)
}

func (s *orderStore) Upsert(ctx context.Context, account accounts.Account) error {
	return s.inner.Upsert(ctx, account)
}
func (s *orderStore) Get(ctx context.Context, id string) (accounts.Account, bool) {
	return s.inner.Get(ctx, id)
}
func (s *orderStore) List(ctx context.Context) []accounts.Account {
	return s.inner.List(ctx)
}
func (s *orderStore) Delete(ctx context.Context, id string) error {
	if s.onDelete != nil {
		s.onDelete(id)
	}
	return s.inner.Delete(ctx, id)
}
