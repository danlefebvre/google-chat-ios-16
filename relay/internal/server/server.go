package server

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/events"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mutes"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/preview"
)

// Publisher publishes notifications (usually *ntfy.Client).
type Publisher interface {
	Publish(n ntfy.Notification) error
}

// Deps wires relay handlers.
type Deps struct {
	Accounts      accounts.Store
	Mutes         *mutes.Rules
	Ntfy          Publisher
	Subscriptions accounts.SubscriptionDeleter
	Tokens        accounts.TokenRevoker
	Labels        map[string]string
	Now           func() time.Time
}

// Server is the HTTP API for the notification relay.
type Server struct {
	deps Deps
	mux  *http.ServeMux
}

// New constructs a Server.
func New(deps Deps) *Server {
	if deps.Now == nil {
		deps.Now = time.Now
	}
	if deps.Mutes == nil {
		deps.Mutes = mutes.NewRules()
	}
	s := &Server{deps: deps, mux: http.NewServeMux()}
	s.mux.HandleFunc("GET /healthz", s.handleHealth)
	s.mux.HandleFunc("POST /v1/test/publish", s.handleTestPublish)
	s.mux.HandleFunc("POST /v1/pubsub/push", s.handlePubSubPush)
	s.mux.HandleFunc("DELETE /v1/accounts/{accountID}", s.handleTeardown)
	return s
}

// Handler returns the root HTTP handler.
func (s *Server) Handler() http.Handler {
	return s.mux
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

type testPublishRequest struct {
	AccountLabel string `json:"accountLabel"`
	SpaceTitle   string `json:"spaceTitle"`
	Sender       string `json:"sender"`
	Text         string `json:"text"`
}

func (s *Server) handleTestPublish(w http.ResponseWriter, r *http.Request) {
	if s.deps.Ntfy == nil {
		http.Error(w, "ntfy not configured", http.StatusServiceUnavailable)
		return
	}
	var req testPublishRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	n := preview.Format(preview.Message{
		AccountLabel: req.AccountLabel,
		SpaceTitle:   req.SpaceTitle,
		Sender:       req.Sender,
		Text:         req.Text,
	})
	if err := s.deps.Ntfy.Publish(ntfy.Notification{
		Title: n.Title,
		Body:  n.Body,
		Tags:  []string{"chat"},
	}); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "published"})
}

func (s *Server) handlePubSubPush(w http.ResponseWriter, r *http.Request) {
	raw, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "read body", http.StatusBadRequest)
		return
	}
	ev, err := events.ParsePush(raw)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if !s.deps.Mutes.ShouldNotify(mutes.Event{
		AccountID: ev.AccountID,
		SpaceName: ev.SpaceName,
		At:        s.deps.Now(),
	}) {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	label := ev.AccountID
	if s.deps.Accounts != nil {
		if acc, ok := s.deps.Accounts.Get(ev.AccountID); ok && acc.Label != "" {
			label = acc.Label
		}
	}
	if s.deps.Labels != nil {
		if l, ok := s.deps.Labels[ev.AccountID]; ok {
			label = l
		}
	}

	if s.deps.Ntfy == nil {
		http.Error(w, "ntfy not configured", http.StatusServiceUnavailable)
		return
	}
	n := preview.Format(preview.Message{
		AccountLabel: label,
		SpaceTitle:   ev.SpaceTitle,
		Sender:       ev.Sender,
		Text:         ev.Text,
	})
	if err := s.deps.Ntfy.Publish(ntfy.Notification{
		Title: n.Title,
		Body:  n.Body,
		Tags:  []string{"chat"},
	}); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleTeardown(w http.ResponseWriter, r *http.Request) {
	accountID, err := url.PathUnescape(r.PathValue("accountID"))
	if err != nil || accountID == "" {
		http.Error(w, "account id required", http.StatusBadRequest)
		return
	}
	if err := accounts.Teardown(s.deps.Accounts, s.deps.Subscriptions, s.deps.Tokens, accountID); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(v)
}
