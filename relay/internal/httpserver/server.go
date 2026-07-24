package httpserver

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/events"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mute"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
)

// Publisher is the ntfy publisher interface.
type Publisher interface {
	Publish(ctx context.Context, msg ntfy.Message) error
}

// Deps wires HTTP handlers.
type Deps struct {
	Accounts          accounts.Store
	Mutes             *mute.Store
	Handler           *events.Handler
	Publisher         Publisher
	Teardown          accounts.Teardown
	PubSubVerifyToken string
}

// Server is the relay HTTP API.
type Server struct {
	Handler http.Handler
	deps    Deps
}

func New(deps Deps) *Server {
	s := &Server{deps: deps}
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealth)
	mux.HandleFunc("/v1/notify/test", s.handleTestNotify)
	mux.HandleFunc("/v1/pubsub/push", s.handlePubSubPush)
	mux.HandleFunc("/v1/accounts/", s.handleAccounts)
	mux.HandleFunc("/v1/accounts", s.handleAccountsCollection)
	mux.HandleFunc("/v1/mutes", s.handleMutes)
	s.Handler = mux
	return s
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

func (s *Server) handleTestNotify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if s.deps.Publisher == nil {
		http.Error(w, "publisher not configured", http.StatusServiceUnavailable)
		return
	}
	var body struct {
		Title string `json:"title"`
		Body  string `json:"body"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	if body.Title == "" || body.Body == "" {
		http.Error(w, "title and body required", http.StatusBadRequest)
		return
	}
	if err := s.deps.Publisher.Publish(r.Context(), ntfy.Message{
		Title: body.Title,
		Body:  body.Body,
		Tags:  []string{"test"},
	}); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"published": true})
}

func (s *Server) handlePubSubPush(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if s.deps.PubSubVerifyToken != "" && r.URL.Query().Get("token") != s.deps.PubSubVerifyToken {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	raw, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "read body", http.StatusBadRequest)
		return
	}
	in, err := events.ParsePubSubPush(raw)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := s.deps.Handler.Handle(r.Context(), in); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleAccountsCollection(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		list := s.deps.Accounts.List(r.Context())
		out := make([]map[string]any, 0, len(list))
		for _, a := range list {
			out = append(out, map[string]any{
				"id":               a.ID,
				"email":            a.Email,
				"label":            a.Label,
				"subscriptionName": a.SubscriptionName,
				"ntfyBound":       a.NtfyBound,
			})
		}
		writeJSON(w, http.StatusOK, map[string]any{"accounts": out})
	case http.MethodPost:
		var body struct {
			ID           string `json:"id"`
			Email        string `json:"email"`
			Label        string `json:"label"`
			RefreshToken string `json:"refreshToken"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}
		if body.ID == "" || body.RefreshToken == "" {
			http.Error(w, "id and refreshToken required", http.StatusBadRequest)
			return
		}
		acc := accounts.Account{
			ID:           body.ID,
			Email:        body.Email,
			Label:        body.Label,
			RefreshToken: body.RefreshToken,
			NtfyBound:   true,
		}
		if err := s.deps.Accounts.Upsert(r.Context(), acc); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{"id": acc.ID})
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleAccounts(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/v1/accounts/")
	id = strings.TrimSpace(id)
	if id == "" {
		http.NotFound(w, r)
		return
	}
	if r.Method != http.MethodDelete {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := s.deps.Teardown.RemoveAccount(r.Context(), id); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleMutes(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var body struct {
		AccountID string `json:"accountId"`
		SpaceName string `json:"spaceName"`
		Muted     bool   `json:"muted"`
		Scope     string `json:"scope"` // account|space
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	if body.AccountID == "" {
		http.Error(w, "accountId required", http.StatusBadRequest)
		return
	}
	scope := body.Scope
	if scope == "" {
		if body.SpaceName != "" {
			scope = "space"
		} else {
			scope = "account"
		}
	}
	switch scope {
	case "account":
		if body.Muted {
			s.deps.Mutes.MuteAccount(body.AccountID)
		} else {
			s.deps.Mutes.UnmuteAccount(body.AccountID)
		}
	case "space":
		if body.SpaceName == "" {
			http.Error(w, "spaceName required", http.StatusBadRequest)
			return
		}
		if body.Muted {
			s.deps.Mutes.MuteSpace(body.AccountID, body.SpaceName)
		} else {
			s.deps.Mutes.UnmuteSpace(body.AccountID, body.SpaceName)
		}
	default:
		http.Error(w, "invalid scope", http.StatusBadRequest)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
