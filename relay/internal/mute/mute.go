package mute

import "sync"

// Store tracks per-account and per-space mute preferences.
type Store struct {
	mu            sync.RWMutex
	mutedAccounts map[string]struct{}
	mutedSpaces   map[string]map[string]struct{} // accountID -> spaceName
}

func NewStore() *Store {
	return &Store{
		mutedAccounts: make(map[string]struct{}),
		mutedSpaces:   make(map[string]map[string]struct{}),
	}
}

func (s *Store) MuteAccount(accountID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.mutedAccounts[accountID] = struct{}{}
}

func (s *Store) UnmuteAccount(accountID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.mutedAccounts, accountID)
}

func (s *Store) MuteSpace(accountID, spaceName string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.mutedSpaces[accountID] == nil {
		s.mutedSpaces[accountID] = make(map[string]struct{})
	}
	s.mutedSpaces[accountID][spaceName] = struct{}{}
}

func (s *Store) UnmuteSpace(accountID, spaceName string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if spaces, ok := s.mutedSpaces[accountID]; ok {
		delete(spaces, spaceName)
		if len(spaces) == 0 {
			delete(s.mutedSpaces, accountID)
		}
	}
}

func (s *Store) ShouldNotify(accountID, spaceName string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if _, ok := s.mutedAccounts[accountID]; ok {
		return false
	}
	if spaces, ok := s.mutedSpaces[accountID]; ok {
		if _, muted := spaces[spaceName]; muted {
			return false
		}
	}
	return true
}

// ClearAccount removes all mute state for an account (teardown helper).
func (s *Store) ClearAccount(accountID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.mutedAccounts, accountID)
	delete(s.mutedSpaces, accountID)
}
