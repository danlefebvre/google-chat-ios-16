package subscriptions

import (
	"context"
	"time"
)

// NoopClient is a local/dev Workspace Events client that does not call Google.
type NoopClient struct{}

// Create invents a subscription id and a one-week expiry.
func (NoopClient) Create(ctx context.Context, accountID, targetPubSub string) (string, time.Time, error) {
	_ = ctx
	_ = targetPubSub
	return "subscriptions/local-" + accountID, time.Now().UTC().Add(7 * 24 * time.Hour), nil
}

// Renew extends expiry by one week.
func (NoopClient) Renew(ctx context.Context, subscriptionID string) (time.Time, error) {
	_ = ctx
	_ = subscriptionID
	return time.Now().UTC().Add(7 * 24 * time.Hour), nil
}

// Delete is a no-op success.
func (NoopClient) Delete(ctx context.Context, subscriptionID string) error {
	_ = ctx
	_ = subscriptionID
	return nil
}
