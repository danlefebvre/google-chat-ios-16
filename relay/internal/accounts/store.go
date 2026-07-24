package accounts

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"sync"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/crypto"
)

// Account is a Google account bound to the relay for Workspace Events → ntfy.
type Account struct {
	ID             string `json:"id"`
	Email          string `json:"email"`
	Label          string `json:"label"`
	RefreshToken   string `json:"-"`
	SubscriptionID string `json:"subscriptionId"`
	NtfyTopic      string `json:"ntfyTopic"`
}

type persistedAccount struct {
	ID                    string `json:"id"`
	Email                 string `json:"email"`
	Label                 string `json:"label"`
	EncryptedRefreshToken string `json:"encryptedRefreshToken"`
	SubscriptionID        string `json:"subscriptionId"`
	NtfyTopic             string `json:"ntfyTopic"`
}

type fileShape struct {
	Accounts []persistedAccount `json:"accounts"`
}

// TeardownHooks run in plan order before wiping local state:
// (1) delete Workspace Events subscription
// (2) revoke/delete refresh token
// (3) invalidate ntfy binding
type TeardownHooks struct {
	DeleteSubscription    func(ctx context.Context, subscriptionID string) error
	RevokeRefreshToken    func(ctx context.Context, refreshToken string) error
	InvalidateNtfyBinding func(ctx context.Context, accountID, topic string) error
}

// Store persists encrypted Google refresh tokens and subscription bindings.
type Store struct {
	mu      sync.RWMutex
	path    string
	key     []byte
	byID    map[string]Account
}

// Open loads or creates an encrypted accounts store at path.
func Open(path string, key []byte) (*Store, error) {
	s := &Store{
		path: path,
		key:  key,
		byID: map[string]Account{},
	}
	if _, err := os.Stat(path); err != nil {
		if os.IsNotExist(err) {
			if err := s.persistLocked(); err != nil {
				return nil, err
			}
			return s, nil
		}
		return nil, err
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var shape fileShape
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &shape); err != nil {
			return nil, fmt.Errorf("decode accounts file: %w", err)
		}
	}
	for _, p := range shape.Accounts {
		token := ""
		if p.EncryptedRefreshToken != "" {
			cipher, err := base64.StdEncoding.DecodeString(p.EncryptedRefreshToken)
			if err != nil {
				return nil, fmt.Errorf("decode token for %s: %w", p.ID, err)
			}
			plain, err := crypto.Decrypt(key, cipher)
			if err != nil {
				return nil, fmt.Errorf("decrypt token for %s: %w", p.ID, err)
			}
			token = string(plain)
		}
		s.byID[p.ID] = Account{
			ID:             p.ID,
			Email:          p.Email,
			Label:          p.Label,
			RefreshToken:   token,
			SubscriptionID: p.SubscriptionID,
			NtfyTopic:      p.NtfyTopic,
		}
	}
	return s, nil
}

// Upsert inserts or updates an account and encrypts the refresh token at rest.
func (s *Store) Upsert(ctx context.Context, acct Account) error {
	_ = ctx
	s.mu.Lock()
	defer s.mu.Unlock()
	s.byID[acct.ID] = acct
	return s.persistLocked()
}

// Get returns an account by immutable issuer|sub id.
func (s *Store) Get(id string) (Account, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.byID[id]
	return a, ok
}

// List returns all accounts.
func (s *Store) List() []Account {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Account, 0, len(s.byID))
	for _, a := range s.byID {
		out = append(out, a)
	}
	return out
}

// Remove tears down remote bindings then deletes local state.
func (s *Store) Remove(ctx context.Context, id string, hooks TeardownHooks) error {
	s.mu.Lock()
	acct, ok := s.byID[id]
	s.mu.Unlock()
	if !ok {
		return nil
	}

	if hooks.DeleteSubscription != nil && acct.SubscriptionID != "" {
		if err := hooks.DeleteSubscription(ctx, acct.SubscriptionID); err != nil {
			return fmt.Errorf("delete workspace subscription: %w", err)
		}
	}
	if hooks.RevokeRefreshToken != nil && acct.RefreshToken != "" {
		if err := hooks.RevokeRefreshToken(ctx, acct.RefreshToken); err != nil {
			return fmt.Errorf("revoke refresh token: %w", err)
		}
	}
	if hooks.InvalidateNtfyBinding != nil {
		if err := hooks.InvalidateNtfyBinding(ctx, acct.ID, acct.NtfyTopic); err != nil {
			return fmt.Errorf("invalidate ntfy binding: %w", err)
		}
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	current, ok := s.byID[id]
	if !ok {
		return nil
	}
	// Skip delete if a concurrent Upsert replaced the record mid-teardown.
	if current.SubscriptionID != acct.SubscriptionID || current.RefreshToken != acct.RefreshToken {
		return nil
	}
	delete(s.byID, id)
	return s.persistLocked()
}

// RawBytes returns the on-disk representation (for tests / debugging).
func (s *Store) RawBytes() ([]byte, error) {
	return os.ReadFile(s.path)
}

func (s *Store) persistLocked() error {
	shape := fileShape{Accounts: make([]persistedAccount, 0, len(s.byID))}
	for _, a := range s.byID {
		enc := ""
		if a.RefreshToken != "" {
			cipher, err := crypto.Encrypt(s.key, []byte(a.RefreshToken))
			if err != nil {
				return err
			}
			enc = base64.StdEncoding.EncodeToString(cipher)
		}
		shape.Accounts = append(shape.Accounts, persistedAccount{
			ID:                    a.ID,
			Email:                 a.Email,
			Label:                 a.Label,
			EncryptedRefreshToken: enc,
			SubscriptionID:        a.SubscriptionID,
			NtfyTopic:             a.NtfyTopic,
		})
	}
	raw, err := json.MarshalIndent(shape, "", "  ")
	if err != nil {
		return err
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, raw, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, s.path)
}
