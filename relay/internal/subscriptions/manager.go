package subscriptions

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// Client talks to Google Workspace Events API.
type Client interface {
	Create(ctx context.Context, accountID, targetPubSub string) (subscriptionID string, expireTime time.Time, err error)
	Renew(ctx context.Context, subscriptionID string) (expireTime time.Time, err error)
	Delete(ctx context.Context, subscriptionID string) error
}

// Record tracks a Workspace Events subscription TTL.
type Record struct {
	AccountID      string
	SubscriptionID string
	ExpireTime     time.Time
}

// Manager refreshes subscription TTLs before expiry.
type Manager struct {
	mu      sync.Mutex
	client  Client
	byAcct  map[string]Record
	renewIn time.Duration
	now     func() time.Time
}

// NewManager builds a subscription TTL manager.
// renewIn is how long before expiry a renew should run (default 24h).
func NewManager(client Client, renewIn time.Duration) *Manager {
	if renewIn <= 0 {
		renewIn = 24 * time.Hour
	}
	return &Manager{
		client:  client,
		byAcct:  map[string]Record{},
		renewIn: renewIn,
		now:     time.Now,
	}
}

// Track registers a subscription for TTL refresh.
func (m *Manager) Track(rec Record) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.byAcct[rec.AccountID] = rec
}

// Untrack drops a subscription from refresh tracking.
func (m *Manager) Untrack(accountID string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.byAcct, accountID)
}

// RefreshDue renews any subscriptions within renewIn of expiry.
func (m *Manager) RefreshDue(ctx context.Context) (renewed int, err error) {
	m.mu.Lock()
	snapshot := make([]Record, 0, len(m.byAcct))
	for _, r := range m.byAcct {
		snapshot = append(snapshot, r)
	}
	m.mu.Unlock()

	deadline := m.now().Add(m.renewIn)
	for _, r := range snapshot {
		if r.ExpireTime.After(deadline) {
			continue
		}
		exp, err := m.client.Renew(ctx, r.SubscriptionID)
		if err != nil {
			return renewed, fmt.Errorf("renew %s: %w", r.SubscriptionID, err)
		}
		r.ExpireTime = exp
		m.Track(r)
		renewed++
	}
	return renewed, nil
}

// Delete removes the remote subscription and untracks it.
func (m *Manager) Delete(ctx context.Context, accountID string) error {
	m.mu.Lock()
	rec, ok := m.byAcct[accountID]
	m.mu.Unlock()
	if !ok {
		return nil
	}
	if err := m.client.Delete(ctx, rec.SubscriptionID); err != nil {
		return err
	}
	m.Untrack(accountID)
	return nil
}
