package mutes

import (
	"sync"
	"time"
)

// Event is the minimal context needed for mute/quiet-hour decisions.
type Event struct {
	AccountID string
	SpaceName string
	At        time.Time
}

// QuietHours suppresses notifications in a daily window (local minutes from midnight).
// If StartMinute > EndMinute the window wraps midnight (e.g. 22:00–07:00).
type QuietHours struct {
	StartMinute int
	EndMinute   int
	Location    *time.Location
	Enabled     bool
}

// Rules holds mute state for accounts/spaces and optional quiet hours.
type Rules struct {
	mu           sync.RWMutex
	mutedAccounts map[string]struct{}
	mutedSpaces   map[string]struct{} // key: accountID + "\x00" + spaceName
	quiet         QuietHours
}

// NewRules returns empty mute rules.
func NewRules() *Rules {
	return &Rules{
		mutedAccounts: make(map[string]struct{}),
		mutedSpaces:   make(map[string]struct{}),
	}
}

// MuteAccount suppresses all notifications for an account.
func (r *Rules) MuteAccount(accountID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.mutedAccounts[accountID] = struct{}{}
}

// UnmuteAccount clears an account mute.
func (r *Rules) UnmuteAccount(accountID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.mutedAccounts, accountID)
}

// MuteSpace suppresses notifications for one space under an account.
func (r *Rules) MuteSpace(accountID, spaceName string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.mutedSpaces[spaceKey(accountID, spaceName)] = struct{}{}
}

// UnmuteSpace clears a space mute.
func (r *Rules) UnmuteSpace(accountID, spaceName string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.mutedSpaces, spaceKey(accountID, spaceName))
}

// SetQuietHours configures quiet hours. Pass Enabled implicitly by calling this.
func (r *Rules) SetQuietHours(qh QuietHours) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if qh.Location == nil {
		qh.Location = time.UTC
	}
	qh.Enabled = true
	r.quiet = qh
}

// ClearQuietHours disables quiet hours.
func (r *Rules) ClearQuietHours() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.quiet = QuietHours{}
}

// ShouldNotify reports whether an event should be published to ntfy.
func (r *Rules) ShouldNotify(ev Event) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if _, ok := r.mutedAccounts[ev.AccountID]; ok {
		return false
	}
	if _, ok := r.mutedSpaces[spaceKey(ev.AccountID, ev.SpaceName)]; ok {
		return false
	}
	if r.quiet.Enabled && inQuietHours(ev.At, r.quiet) {
		return false
	}
	return true
}

func spaceKey(accountID, spaceName string) string {
	return accountID + "\x00" + spaceName
}

func inQuietHours(at time.Time, qh QuietHours) bool {
	local := at.In(qh.Location)
	minute := local.Hour()*60 + local.Minute()
	if qh.StartMinute == qh.EndMinute {
		return false
	}
	if qh.StartMinute < qh.EndMinute {
		return minute >= qh.StartMinute && minute < qh.EndMinute
	}
	// wraps midnight
	return minute >= qh.StartMinute || minute < qh.EndMinute
}
