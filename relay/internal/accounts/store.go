package accounts

import (
	"fmt"
	"sync"
)

// Account is a Google account bound to the relay for events → ntfy.
type Account struct {
	ID           string
	Email        string
	Label        string
	RefreshToken string
	Subscription string
	NtfyTopic    string
}

// Store persists account bindings used by the relay.
type Store interface {
	Upsert(Account) error
	Get(id string) (Account, bool)
	Delete(id string) error
	List() []Account
}

// MemoryStore is an in-memory Store for tests and single-instance deploys.
type MemoryStore struct {
	mu   sync.RWMutex
	byID map[string]Account
}

// NewMemoryStore creates an empty memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{byID: make(map[string]Account)}
}

func (s *MemoryStore) Upsert(a Account) error {
	if a.ID == "" {
		return fmt.Errorf("account id required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.byID[a.ID] = a
	return nil
}

func (s *MemoryStore) Get(id string) (Account, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.byID[id]
	return a, ok
}

func (s *MemoryStore) Delete(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.byID, id)
	return nil
}

func (s *MemoryStore) List() []Account {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Account, 0, len(s.byID))
	for _, a := range s.byID {
		out = append(out, a)
	}
	return out
}

// SubscriptionDeleter deletes a Workspace Events subscription.
type SubscriptionDeleter interface {
	DeleteSubscription(name string) error
}

// TokenRevoker revokes or deletes a stored refresh token.
type TokenRevoker interface {
	Revoke(accountID string) error
}

// Teardown removes relay-side state for an account in the locked order:
// (1) delete Workspace Events subscription
// (2) revoke/delete refresh token
// (3) remove ntfy binding / account record
func Teardown(store Store, subs SubscriptionDeleter, tokens TokenRevoker, accountID string) error {
	acc, ok := store.Get(accountID)
	if !ok {
		return fmt.Errorf("account not found: %s", accountID)
	}
	if acc.Subscription != "" && subs != nil {
		if err := subs.DeleteSubscription(acc.Subscription); err != nil {
			return fmt.Errorf("delete subscription: %w", err)
		}
	}
	if tokens != nil {
		if err := tokens.Revoke(accountID); err != nil {
			return fmt.Errorf("revoke token: %w", err)
		}
	}
	if err := store.Delete(accountID); err != nil {
		return fmt.Errorf("delete binding: %w", err)
	}
	return nil
}
