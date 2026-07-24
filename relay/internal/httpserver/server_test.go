package httpserver_test

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/events"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/httpserver"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mute"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/quiet"
)

func TestHealth(t *testing.T) {
	t.Parallel()
	srv := httpserver.New(httpserver.Deps{
		Accounts: accounts.NewMemoryStore(),
		Mutes:    mute.NewStore(),
		Handler:  events.NewHandler(&noopPub{}, mute.NewStore(), quiet.Hours{}, time.UTC),
	})
	res := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	srv.Handler.ServeHTTP(w, res)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), `"ok"`) {
		t.Fatalf("body = %s", w.Body.String())
	}
}

func TestManualPublish(t *testing.T) {
	t.Parallel()

	var gotTitle, gotBody string
	fakeNtfy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotTitle = r.Header.Get("Title")
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		w.WriteHeader(http.StatusOK)
	}))
	t.Cleanup(fakeNtfy.Close)

	pub := ntfy.NewPublisher(fakeNtfy.URL, "topic", "", fakeNtfy.Client())
	mutes := mute.NewStore()
	srv := httpserver.New(httpserver.Deps{
		Accounts: accounts.NewMemoryStore(),
		Mutes:    mutes,
		Handler:  events.NewHandler(pub, mutes, quiet.Hours{}, time.UTC),
		Publisher: pub,
	})

	body := `{"title":"[Work] test","body":"Alice: hello"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/notify/test", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	srv.Handler.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d body=%s", w.Code, w.Body.String())
	}
	if gotTitle != "[Work] test" || gotBody != "Alice: hello" {
		t.Fatalf("title=%q body=%q", gotTitle, gotBody)
	}
}

func TestPubSubPushEndpoint(t *testing.T) {
	t.Parallel()

	pub := &capturePub{}
	mutes := mute.NewStore()
	h := events.NewHandler(pub, mutes, quiet.Hours{}, time.UTC)
	srv := httpserver.New(httpserver.Deps{
		Accounts: accounts.NewMemoryStore(),
		Mutes:    mutes,
		Handler:  h,
		Publisher: pub,
		PubSubVerifyToken: "verify-me",
	})

	payload := map[string]any{
		"message": map[string]any{
			"data": "eyJhY2NvdW50SWQiOiJpc3N8d29yayIsImFjY291bnRMYWJlbCI6IldvcmsiLCJzcGFjZU5hbWUiOiJzcGFjZXMvQUFBIiwic3BhY2VUaXRsZSI6IiNlbmctc3RhbmR1cCIsInNlbmRlck5hbWUiOiJBbGljZSIsInRleHQiOiJkZXBsb3kgbG9va3MgZ29vZCIsIm9jY3VycmVkQXQiOiIyMDI2LTA3LTI0VDEyOjAwOjAwWiJ9",
		},
	}
	b, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/v1/pubsub/push?token=verify-me", bytes.NewReader(b))
	w := httptest.NewRecorder()
	srv.Handler.ServeHTTP(w, req)
	if w.Code != http.StatusNoContent {
		t.Fatalf("status = %d body=%s", w.Code, w.Body.String())
	}
	if len(pub.msgs) != 1 {
		t.Fatalf("published %d", len(pub.msgs))
	}
}

func TestRemoveAccountEndpoint(t *testing.T) {
	t.Parallel()

	store := accounts.NewMemoryStore()
	_ = store.Upsert(context.Background(), accounts.Account{
		ID:               "iss|work",
		RefreshToken:     "rt",
		SubscriptionName: "subscriptions/1",
		NtfyBound:       true,
	})
	var deletedSub, revoked string
	srv := httpserver.New(httpserver.Deps{
		Accounts: store,
		Mutes:    mute.NewStore(),
		Handler:  events.NewHandler(&noopPub{}, mute.NewStore(), quiet.Hours{}, time.UTC),
		Teardown: accounts.Teardown{
			Store: store,
			DeleteSubscription: func(ctx context.Context, name string) error {
				deletedSub = name
				return nil
			},
			RevokeRefreshToken: func(ctx context.Context, token string) error {
				revoked = token
				return nil
			},
			ClearNtfyBinding: func(ctx context.Context, accountID string) error {
				return nil
			},
		},
	})

	req := httptest.NewRequest(http.MethodDelete, "/v1/accounts/iss%7Cwork", nil)
	w := httptest.NewRecorder()
	srv.Handler.ServeHTTP(w, req)
	if w.Code != http.StatusNoContent {
		t.Fatalf("status = %d body=%s", w.Code, w.Body.String())
	}
	if deletedSub != "subscriptions/1" || revoked != "rt" {
		t.Fatalf("deletedSub=%q revoked=%q", deletedSub, revoked)
	}
	if _, ok := store.Get(context.Background(), "iss|work"); ok {
		t.Fatal("account still present")
	}
}

type noopPub struct{}

func (noopPub) Publish(ctx context.Context, msg ntfy.Message) error { return nil }

type capturePub struct {
	msgs []ntfy.Message
}

func (p *capturePub) Publish(ctx context.Context, msg ntfy.Message) error {
	p.msgs = append(p.msgs, msg)
	return nil
}
