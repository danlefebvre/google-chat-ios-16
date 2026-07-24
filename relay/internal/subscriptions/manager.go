package subscriptions

import (
	"context"
	"fmt"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
)

// Manager refreshes Workspace Events subscription TTLs before expiry.
type Manager struct {
	Store          accounts.Store
	Renew          func(ctx context.Context, accountID, subscriptionName string) (newName string, expires time.Time, err error)
	OnRenewFailure func(ctx context.Context, account accounts.Account, err error)
	RenewWithin    time.Duration
	Now            func() time.Time
}

func (m Manager) RefreshExpiring(ctx context.Context) error {
	now := time.Now().UTC()
	if m.Now != nil {
		now = m.Now()
	}
	within := m.RenewWithin
	if within == 0 {
		within = 24 * time.Hour
	}
	var firstErr error
	for _, acc := range m.Store.List(ctx) {
		if acc.SubscriptionName == "" {
			continue
		}
		if acc.SubscriptionExp.IsZero() || acc.SubscriptionExp.After(now.Add(within)) {
			continue
		}
		newName, exp, err := m.Renew(ctx, acc.ID, acc.SubscriptionName)
		if err != nil {
			if m.OnRenewFailure != nil {
				m.OnRenewFailure(ctx, acc, err)
			}
			if firstErr == nil {
				firstErr = fmt.Errorf("renew %s: %w", acc.ID, err)
			}
			continue
		}
		acc.SubscriptionName = newName
		acc.SubscriptionExp = exp
		if err := m.Store.Upsert(ctx, acc); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return firstErr
}
