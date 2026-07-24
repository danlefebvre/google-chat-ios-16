package subscriptions

import (
	"fmt"
	"sync"
	"time"
)

// RemoteSubscription is a Workspace Events subscription.
type RemoteSubscription struct {
	Name       string
	AccountID  string
	ExpireTime time.Time
}

// API talks to Google Workspace Events.
type API interface {
	Create(accountID, pubsubTopic string) (RemoteSubscription, error)
	Patch(name string, expire time.Time) (RemoteSubscription, error)
	Delete(name string) error
}

// Manager tracks subscriptions and refreshes TTLs before expiry.
type Manager struct {
	api         API
	mu          sync.Mutex
	byAccount   map[string]RemoteSubscription
	Now         func() time.Time
	RefreshLead time.Duration
	TTL         time.Duration
}

// NewManager constructs a subscription manager.
func NewManager(api API) *Manager {
	return &Manager{
		api:         api,
		byAccount:   make(map[string]RemoteSubscription),
		Now:         time.Now,
		RefreshLead: 24 * time.Hour,
		TTL:         7 * 24 * time.Hour,
	}
}

// Ensure creates a subscription for accountID if missing.
func (m *Manager) Ensure(accountID, pubsubTopic string) (RemoteSubscription, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if sub, ok := m.byAccount[accountID]; ok {
		return sub, nil
	}
	sub, err := m.api.Create(accountID, pubsubTopic)
	if err != nil {
		return RemoteSubscription{}, err
	}
	sub.AccountID = accountID
	m.byAccount[accountID] = sub
	return sub, nil
}

// RefreshDue patches subscriptions within RefreshLead of expiry.
func (m *Manager) RefreshDue() (int, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	now := m.Now()
	count := 0
	for accountID, sub := range m.byAccount {
		if sub.ExpireTime.After(now.Add(m.RefreshLead)) {
			continue
		}
		updated, err := m.api.Patch(sub.Name, now.Add(m.TTL))
		if err != nil {
			return count, fmt.Errorf("refresh %s: %w", sub.Name, err)
		}
		updated.AccountID = accountID
		m.byAccount[accountID] = updated
		count++
	}
	return count, nil
}

// DeleteSubscription deletes a remote subscription and drops local tracking.
func (m *Manager) DeleteSubscription(name string) error {
	if err := m.api.Delete(name); err != nil {
		return err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	for id, sub := range m.byAccount {
		if sub.Name == name {
			delete(m.byAccount, id)
			break
		}
	}
	return nil
}
