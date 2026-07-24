package mutes

import (
	"fmt"
	"sync"
	"time"
)

// QuietHours suppresses notifications in a local time window (supports overnight ranges).
type QuietHours struct {
	Enabled   bool
	StartHour int
	EndHour   int
	Location  *time.Location
}

// Policy decides whether a chat event should produce an ntfy publish.
type Policy struct {
	mu            sync.RWMutex
	mutedAccounts map[string]bool
	mutedSpaces   map[string]bool
	quiet         QuietHours
}

// NewPolicy builds a mute/quiet-hours policy. Nil maps are treated as empty.
func NewPolicy(mutedAccounts, mutedSpaces map[string]bool, quiet QuietHours) *Policy {
	if mutedAccounts == nil {
		mutedAccounts = map[string]bool{}
	}
	if mutedSpaces == nil {
		mutedSpaces = map[string]bool{}
	}
	if quiet.Location == nil {
		quiet.Location = time.UTC
	}
	return &Policy{
		mutedAccounts: mutedAccounts,
		mutedSpaces:   mutedSpaces,
		quiet:         quiet,
	}
}

// SpaceKey builds the composite mute key for an account + space resource name.
func SpaceKey(accountID, spaceName string) string {
	return fmt.Sprintf("%s:%s", accountID, spaceName)
}

// ShouldNotify returns false when the account/space is muted or quiet hours apply.
func (p *Policy) ShouldNotify(accountID, spaceName string, at time.Time) bool {
	p.mu.RLock()
	defer p.mu.RUnlock()
	if p.mutedAccounts[accountID] {
		return false
	}
	if p.mutedSpaces[SpaceKey(accountID, spaceName)] {
		return false
	}
	if p.inQuietHours(at) {
		return false
	}
	return true
}

// SetAccountMuted updates account-level mute state.
func (p *Policy) SetAccountMuted(accountID string, muted bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if muted {
		p.mutedAccounts[accountID] = true
		return
	}
	delete(p.mutedAccounts, accountID)
}

// SetSpaceMuted updates per-space mute state.
func (p *Policy) SetSpaceMuted(accountID, spaceName string, muted bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	key := SpaceKey(accountID, spaceName)
	if muted {
		p.mutedSpaces[key] = true
		return
	}
	delete(p.mutedSpaces, key)
}

func (p *Policy) inQuietHours(at time.Time) bool {
	if !p.quiet.Enabled {
		return false
	}
	local := at.In(p.quiet.Location)
	hour := local.Hour()
	start := p.quiet.StartHour
	end := p.quiet.EndHour
	if start == end {
		return true
	}
	if start < end {
		return hour >= start && hour < end
	}
	// Overnight window, e.g. 22 → 7
	return hour >= start || hour < end
}
