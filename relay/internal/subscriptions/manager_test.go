package subscriptions_test

import (
	"context"
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/subscriptions"
)

type fakeClient struct {
	renewed []string
	deleted []string
	renewTo time.Time
}

func (f *fakeClient) Create(ctx context.Context, accountID, targetPubSub string) (string, time.Time, error) {
	return "subscriptions/" + accountID, time.Now().Add(7 * 24 * time.Hour), nil
}

func (f *fakeClient) Renew(ctx context.Context, subscriptionID string) (time.Time, error) {
	f.renewed = append(f.renewed, subscriptionID)
	return f.renewTo, nil
}

func (f *fakeClient) Delete(ctx context.Context, subscriptionID string) error {
	f.deleted = append(f.deleted, subscriptionID)
	return nil
}

func TestManager_RefreshDueRenewsExpiring(t *testing.T) {
	t.Parallel()

	now := time.Date(2026, 7, 24, 12, 0, 0, 0, time.UTC)
	client := &fakeClient{renewTo: now.Add(7 * 24 * time.Hour)}
	m := subscriptions.NewManager(client, 24*time.Hour)
	m.Track(subscriptions.Record{
		AccountID:      "a1",
		SubscriptionID: "subscriptions/a1",
		ExpireTime:     now.Add(2 * time.Hour),
	})
	m.Track(subscriptions.Record{
		AccountID:      "a2",
		SubscriptionID: "subscriptions/a2",
		ExpireTime:     now.Add(72 * time.Hour),
	})

	// Inject clock via RefreshDue using tracked times relative to real now is hard;
	// instead put a1 in the past relative to current time so it is due.
	m = subscriptions.NewManager(client, 24*time.Hour)
	m.Track(subscriptions.Record{
		AccountID:      "a1",
		SubscriptionID: "subscriptions/a1",
		ExpireTime:     time.Now().Add(1 * time.Hour),
	})
	m.Track(subscriptions.Record{
		AccountID:      "a2",
		SubscriptionID: "subscriptions/a2",
		ExpireTime:     time.Now().Add(72 * time.Hour),
	})

	n, err := m.RefreshDue(context.Background())
	if err != nil {
		t.Fatalf("RefreshDue: %v", err)
	}
	if n != 1 {
		t.Fatalf("renewed = %d, want 1", n)
	}
	if len(client.renewed) != 1 || client.renewed[0] != "subscriptions/a1" {
		t.Fatalf("renewed = %v", client.renewed)
	}
}

func TestManager_Delete(t *testing.T) {
	t.Parallel()

	client := &fakeClient{}
	m := subscriptions.NewManager(client, time.Hour)
	m.Track(subscriptions.Record{AccountID: "a1", SubscriptionID: "subscriptions/a1", ExpireTime: time.Now().Add(time.Hour)})
	if err := m.Delete(context.Background(), "a1"); err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if len(client.deleted) != 1 {
		t.Fatalf("deleted = %v", client.deleted)
	}
}
