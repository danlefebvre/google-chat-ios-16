package accounts

import (
	"context"
	"sync"
	"time"
)

// Account is a Google account bound to the relay for Workspace Events → ntfy.
type Account struct {
	ID               string
	Email            string
	Label            string
	RefreshToken     string
	SubscriptionName string
	SubscriptionExp  time.Time
	NtfyBound       bool
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

// Store persists relay account credentials and bindings.
type Store interface {
	Upsert(ctx context.Context, account Account) error
	Get(ctx context.Context, id string) (Account, bool)
	List(ctx context.Context) []Account
	Delete(ctx context.Context, id string) error
}

// MemoryStore is an in-memory Store for tests and single-instance deploys.
type MemoryStore struct {
	mu   sync.RWMutex
	byID map[string]Account
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{byID: make(map[string]Account)}
}

func (s *MemoryStore) Upsert(ctx context.Context, account Account) error {
	_ = ctx
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().UTC()
	if existing, ok := s.byID[account.ID]; ok {
		account.CreatedAt = existing.CreatedAt
	} else if account.CreatedAt.IsZero() {
		account.CreatedAt = now
	}
	account.UpdatedAt = now
	s.byID[account.ID] = account
	return nil
}

func (s *MemoryStore) Get(ctx context.Context, id string) (Account, bool) {
	_ = ctx
	s.mu.RLock()
	defer s.mu.RUnlock()
	acc, ok := s.byID[id]
	return acc, ok
}

func (s *MemoryStore) List(ctx context.Context) []Account {
	_ = ctx
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Account, 0, len(s.byID))
	for _, acc := range s.byID {
		out = append(out, acc)
	}
	return out
}

func (s *MemoryStore) Delete(ctx context.Context, id string) error {
	_ = ctx
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.byID, id)
	return nil
}
