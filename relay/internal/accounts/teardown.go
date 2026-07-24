package accounts

import (
	"context"
	"fmt"
)

// Teardown removes an account from the relay in the locked order:
// (1) delete Workspace Events subscription
// (2) revoke/delete refresh token
// (3) invalidate ntfy binding
// (4) wipe store entry
type Teardown struct {
	Store              Store
	DeleteSubscription func(ctx context.Context, subscriptionName string) error
	RevokeRefreshToken func(ctx context.Context, refreshToken string) error
	ClearNtfyBinding   func(ctx context.Context, accountID string) error
}

func (t Teardown) RemoveAccount(ctx context.Context, accountID string) error {
	acc, ok := t.Store.Get(ctx, accountID)
	if !ok {
		return fmt.Errorf("account %q not found", accountID)
	}

	if acc.SubscriptionName != "" && t.DeleteSubscription != nil {
		if err := t.DeleteSubscription(ctx, acc.SubscriptionName); err != nil {
			return fmt.Errorf("delete subscription: %w", err)
		}
	}
	if acc.RefreshToken != "" && t.RevokeRefreshToken != nil {
		if err := t.RevokeRefreshToken(ctx, acc.RefreshToken); err != nil {
			return fmt.Errorf("revoke refresh token: %w", err)
		}
	}
	if t.ClearNtfyBinding != nil {
		if err := t.ClearNtfyBinding(ctx, accountID); err != nil {
			return fmt.Errorf("clear ntfy binding: %w", err)
		}
	}
	if err := t.Store.Delete(ctx, accountID); err != nil {
		return fmt.Errorf("delete store entry: %w", err)
	}
	return nil
}
