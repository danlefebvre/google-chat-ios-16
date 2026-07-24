package server_test

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mutes"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/server"
)

func TestHealth_ReturnsOK(t *testing.T) {
	srv := server.New(server.Deps{
		Accounts: accounts.NewMemoryStore(),
		Mutes:    mutes.NewRules(),
		Labels:   map[string]string{"issuer|sub-1": "Work"},
	})
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rr := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
	if body := rr.Body.String(); body != `{"ok":true}`+"\n" && body != `{"ok":true}` {
		// accept either with or without newline from Encode
		var got map[string]bool
		if err := json.Unmarshal(rr.Body.Bytes(), &got); err != nil || !got["ok"] {
			t.Fatalf("body = %q", rr.Body.String())
		}
	}
}

func TestManualPublish_SendsPreviewToNtfy(t *testing.T) {
	var gotTitle, gotBody string
	ntfySrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotTitle = r.Header.Get("Title")
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		w.WriteHeader(http.StatusOK)
	}))
	defer ntfySrv.Close()

	client := ntfy.NewClient(ntfySrv.URL, "topic", "", ntfySrv.Client())
	srv := server.New(server.Deps{
		Accounts: accounts.NewMemoryStore(),
		Mutes:    mutes.NewRules(),
		Ntfy:     client,
		Labels:   map[string]string{},
	})

	body := `{"accountLabel":"Work","spaceTitle":"#eng-standup","sender":"Alice","text":"deploy looks good"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/test/publish", bytes.NewBufferString(body))
	rr := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d body=%s", rr.Code, rr.Body.String())
	}
	if gotTitle != "[Work] #eng-standup" {
		t.Fatalf("title = %q", gotTitle)
	}
	if gotBody != "Alice: deploy looks good" {
		t.Fatalf("body = %q", gotBody)
	}
}

func TestPubSubPush_PublishesWhenNotMuted(t *testing.T) {
	var gotTitle, gotBody string
	ntfySrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotTitle = r.Header.Get("Title")
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		w.WriteHeader(http.StatusOK)
	}))
	defer ntfySrv.Close()

	store := accounts.NewMemoryStore()
	_ = store.Upsert(accounts.Account{
		ID:    "issuer|sub-work",
		Label: "Work",
	})

	client := ntfy.NewClient(ntfySrv.URL, "topic", "", ntfySrv.Client())
	srv := server.New(server.Deps{
		Accounts: store,
		Mutes:    mutes.NewRules(),
		Ntfy:     client,
	})

	inner := `{
		"chatEventData": {
			"messageCreatedEventData": {
				"message": {
					"name": "spaces/AAA/messages/BBB",
					"sender": {"displayName": "Alice"},
					"text": "deploy looks good",
					"space": {"name": "spaces/AAA", "displayName": "#eng-standup"}
				}
			}
		}
	}`
	payload := map[string]any{
		"message": map[string]any{
			"data": base64.StdEncoding.EncodeToString([]byte(inner)),
			"attributes": map[string]string{
				"accountId": "issuer|sub-work",
			},
		},
	}
	raw, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/v1/pubsub/push", bytes.NewReader(raw))
	rr := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("status = %d body=%s", rr.Code, rr.Body.String())
	}
	if gotTitle != "[Work] #eng-standup" {
		t.Fatalf("title = %q", gotTitle)
	}
	if gotBody != "Alice: deploy looks good" {
		t.Fatalf("body = %q", gotBody)
	}
}

func TestPubSubPush_SkipsMutedAccount(t *testing.T) {
	called := false
	ntfySrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))
	defer ntfySrv.Close()

	store := accounts.NewMemoryStore()
	_ = store.Upsert(accounts.Account{ID: "issuer|sub-work", Label: "Work"})
	rules := mutes.NewRules()
	rules.MuteAccount("issuer|sub-work")

	srv := server.New(server.Deps{
		Accounts: store,
		Mutes:    rules,
		Ntfy:     ntfy.NewClient(ntfySrv.URL, "topic", "", ntfySrv.Client()),
	})

	inner := `{"chatEventData":{"messageCreatedEventData":{"message":{"name":"spaces/AAA/messages/BBB","sender":{"displayName":"Alice"},"text":"hi","space":{"name":"spaces/AAA","displayName":"#eng"}}}}}`
	payload := map[string]any{
		"message": map[string]any{
			"data":       base64.StdEncoding.EncodeToString([]byte(inner)),
			"attributes": map[string]string{"accountId": "issuer|sub-work"},
		},
	}
	raw, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/v1/pubsub/push", bytes.NewReader(raw))
	rr := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("status = %d", rr.Code)
	}
	if called {
		t.Fatal("expected muted account to skip ntfy publish")
	}
}

func TestTeardownAccount_Endpoint(t *testing.T) {
	subs := &stubSubs{deleted: map[string]bool{}}
	tokens := &stubTokens{tokens: map[string]string{"issuer|sub-1": "rt"}}
	store := accounts.NewMemoryStore()
	_ = store.Upsert(accounts.Account{
		ID:           "issuer|sub-1",
		Subscription: "subscriptions/sub-1",
		RefreshToken: "rt",
	})

	srv := server.New(server.Deps{
		Accounts:      store,
		Mutes:         mutes.NewRules(),
		Subscriptions: subs,
		Tokens:        tokens,
	})

	req := httptest.NewRequest(http.MethodDelete, "/v1/accounts/issuer%7Csub-1", nil)
	rr := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("status = %d body=%s", rr.Code, rr.Body.String())
	}
	if !subs.deleted["subscriptions/sub-1"] {
		t.Fatal("subscription not deleted")
	}
	if _, ok := store.Get("issuer|sub-1"); ok {
		t.Fatal("account still present")
	}
}

func TestPubSubPush_DedupsRedelivery(t *testing.T) {
	calls := 0
	ntfySrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.WriteHeader(http.StatusOK)
	}))
	defer ntfySrv.Close()

	store := accounts.NewMemoryStore()
	_ = store.Upsert(accounts.Account{ID: "issuer|sub-work", Label: "Work"})
	srv := server.New(server.Deps{
		Accounts: store,
		Mutes:    mutes.NewRules(),
		Ntfy:     ntfy.NewClient(ntfySrv.URL, "topic", "", ntfySrv.Client()),
	})

	inner := `{"chatEventData":{"messageCreatedEventData":{"message":{"name":"spaces/AAA/messages/BBB","sender":{"displayName":"Alice"},"text":"hi","space":{"name":"spaces/AAA","displayName":"#eng"}}}}}`
	payload := map[string]any{
		"message": map[string]any{
			"data":       base64.StdEncoding.EncodeToString([]byte(inner)),
			"attributes": map[string]string{"accountId": "issuer|sub-work"},
		},
	}
	raw, _ := json.Marshal(payload)

	for i := 0; i < 2; i++ {
		req := httptest.NewRequest(http.MethodPost, "/v1/pubsub/push", bytes.NewReader(raw))
		rr := httptest.NewRecorder()
		srv.Handler().ServeHTTP(rr, req)
		if rr.Code != http.StatusNoContent {
			t.Fatalf("status = %d body=%s", rr.Code, rr.Body.String())
		}
	}
	if calls != 1 {
		t.Fatalf("ntfy publish calls = %d, want 1", calls)
	}
}

func TestMutatingRoutes_RequireAPITokenWhenConfigured(t *testing.T) {
	srv := server.New(server.Deps{
		Accounts: accounts.NewMemoryStore(),
		Mutes:    mutes.NewRules(),
		APIToken: "secret",
	})
	req := httptest.NewRequest(http.MethodDelete, "/v1/accounts/issuer%7Csub-1", nil)
	rr := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rr.Code)
	}

	req2 := httptest.NewRequest(http.MethodDelete, "/v1/accounts/issuer%7Cmissing", nil)
	req2.Header.Set("Authorization", "Bearer secret")
	rr2 := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr2, req2)
	if rr2.Code != http.StatusNotFound {
		t.Fatalf("status = %d body=%s", rr2.Code, rr2.Body.String())
	}
}

type stubSubs struct{ deleted map[string]bool }

func (s *stubSubs) DeleteSubscription(name string) error {
	s.deleted[name] = true
	return nil
}

type stubTokens struct{ tokens map[string]string }

func (s *stubTokens) Revoke(accountID string) error {
	delete(s.tokens, accountID)
	return nil
}
