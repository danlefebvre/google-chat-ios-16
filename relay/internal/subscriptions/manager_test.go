package subscriptions_test

import (
	"context"
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/subscriptions"
)

func TestRefreshExpiring_RenewsSoonToExpire(t *testing.T) {
	t.Parallel()

	store := accounts.NewMemoryStore()
	now := time.Date(2026, 7, 24, 12, 0, 0, 0, time.UTC)
	_ = store.Upsert(context.Background(), accounts.Account{
		ID:               "a1",
		SubscriptionName: "subscriptions/old",
		SubscriptionExp:  now.Add(30 * time.Minute),
	})
	_ = store.Upsert(context.Background(), accounts.Account{
		ID:               "a2",
		SubscriptionName: "subscriptions/fresh",
		SubscriptionExp:  now.Add(48 * time.Hour),
	})

	var renewed []string
	mgr := subscriptions.Manager{
		Store: store,
		Now:   func() time.Time { return now },
		Renew: func(ctx context.Context, accountID, subscriptionName string) (string, time.Time, error) {
			renewed = append(renewed, accountID)
			return "subscriptions/new-" + accountID, now.Add(7 * 24 * time.Hour), nil
		},
		RenewWithin: 2 * time.Hour,
	}

	if err := mgr.RefreshExpiring(context.Background()); err != nil {
		t.Fatalf("RefreshExpiring: %v", err)
	}
	if len(renewed) != 1 || renewed[0] != "a1" {
		t.Fatalf("renewed = %v", renewed)
	}
	acc, _ := store.Get(context.Background(), "a1")
	if acc.SubscriptionName != "subscriptions/new-a1" {
		t.Fatalf("name = %q", acc.SubscriptionName)
	}
}

func TestRefreshExpiring_AlertsOnFailure(t *testing.T) {
	t.Parallel()

	store := accounts.NewMemoryStore()
	now := time.Date(2026, 7, 24, 12, 0, 0, 0, time.UTC)
	_ = store.Upsert(context.Background(), accounts.Account{
		ID:               "a1",
		Label:            "Work",
		SubscriptionName: "subscriptions/old",
		SubscriptionExp:  now.Add(10 * time.Minute),
	})

	var alerted bool
	mgr := subscriptions.Manager{
		Store: store,
		Now:   func() time.Time { return now },
		Renew: func(ctx context.Context, accountID, subscriptionName string) (string, time.Time, error) {
			return "", time.Time{}, context.DeadlineExceeded
		},
		OnRenewFailure: func(ctx context.Context, account accounts.Account, err error) {
			alerted = true
		},
		RenewWithin: time.Hour,
	}
	_ = mgr.RefreshExpiring(context.Background())
	if !alerted {
		t.Fatal("expected renew failure alert")
	}
}
