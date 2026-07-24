package pubsub

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/events"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mutes"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
)

// AccountView is the minimal account info needed to publish a notification.
type AccountView struct {
	ID    string
	Label string
}

// AccountLookup resolves relay-bound accounts.
type AccountLookup interface {
	Get(id string) (AccountView, bool)
}

// Handler consumes Pub/Sub push deliveries and publishes ntfy previews.
type Handler struct {
	publisher  ntfy.Publisher
	accounts   AccountLookup
	policy     *mutes.Policy
	clickScheme string
	now        func() time.Time
}

// NewHandler constructs a Pub/Sub push HTTP handler.
func NewHandler(publisher ntfy.Publisher, accounts AccountLookup, policy *mutes.Policy, clickScheme string) http.Handler {
	return &Handler{
		publisher:   publisher,
		accounts:    accounts,
		policy:      policy,
		clickScheme: clickScheme,
		now:         time.Now,
	}
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "read body", http.StatusBadRequest)
		return
	}
	env, err := events.ParsePubSubPush(body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	acct, ok := h.accounts.Get(env.AccountID)
	if !ok {
		// Teardown completed or stale delivery — ack so Pub/Sub stops retrying.
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if !h.policy.ShouldNotify(env.AccountID, env.Message.SpaceName, h.now()) {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	msg := ntfy.Message{
		AccountLabel: acct.Label,
		SpaceTitle:   env.Message.SpaceTitle,
		Sender:       env.Message.Sender,
		Preview:      env.Message.Text,
		ClickURL:     h.clickURL(env.AccountID, env.Message.SpaceName),
	}
	if err := h.publisher.Publish(r.Context(), msg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) clickURL(accountID, spaceName string) string {
	// googlechatmulti://spaces/{accountId}/{urlencoded space resource name}
	return fmt.Sprintf("%s://spaces/%s/%s", h.clickScheme, url.PathEscape(accountID), url.PathEscape(spaceName))
}

// AccountStoreAdapter adapts accounts.Store-like getters to AccountLookup.
type AccountStoreAdapter struct {
	GetFn func(id string) (label string, ok bool)
}

// Get implements AccountLookup.
func (a AccountStoreAdapter) Get(id string) (AccountView, bool) {
	label, ok := a.GetFn(id)
	if !ok {
		return AccountView{}, false
	}
	return AccountView{ID: id, Label: label}, true
}

// PublishManual publishes a test notification (Phase 0 / ops).
func PublishManual(ctx context.Context, publisher ntfy.Publisher, accountLabel, spaceTitle, sender, preview string) error {
	return publisher.Publish(ctx, ntfy.Message{
		AccountLabel: accountLabel,
		SpaceTitle:   spaceTitle,
		Sender:       sender,
		Preview:      preview,
	})
}
