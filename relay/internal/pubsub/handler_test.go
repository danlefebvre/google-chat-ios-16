package pubsub_test

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mutes"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/pubsub"
)

type fakePublisher struct {
	mu   sync.Mutex
	msgs []ntfy.Message
	err  error
}

func (f *fakePublisher) Publish(ctx context.Context, msg ntfy.Message) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return f.err
	}
	f.msgs = append(f.msgs, msg)
	return nil
}

type fakeAccounts struct {
	byID map[string]pubsub.AccountView
}

func (f fakeAccounts) Get(id string) (pubsub.AccountView, bool) {
	a, ok := f.byID[id]
	return a, ok
}

func TestPushHandler_PublishesPreview(t *testing.T) {
	t.Parallel()

	inner, _ := json.Marshal(map[string]any{
		"message": map[string]any{
			"name": "spaces/AAA/messages/BBB",
			"text": "deploy looks good",
			"sender": map[string]any{
				"displayName": "Alice",
			},
			"space": map[string]any{
				"name":        "spaces/AAA",
				"displayName": "#eng-standup",
				"type":        "SPACE",
			},
		},
	})
	body, _ := json.Marshal(map[string]any{
		"message": map[string]any{
			"data":      base64.StdEncoding.EncodeToString(inner),
			"messageId": "1",
			"attributes": map[string]string{
				"accountId": "acct-work",
			},
		},
	})

	pub := &fakePublisher{}
	h := pubsub.NewHandler(pub, fakeAccounts{byID: map[string]pubsub.AccountView{
		"acct-work": {ID: "acct-work", Label: "Work"},
	}}, mutes.NewPolicy(nil, nil, mutes.QuietHours{}), "googlechatmulti")

	req := httptest.NewRequest(http.MethodPost, "/pubsub/push", bytes.NewReader(body))
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)

	if rr.Code != http.StatusNoContent {
		t.Fatalf("status = %d body=%s", rr.Code, rr.Body.String())
	}
	pub.mu.Lock()
	defer pub.mu.Unlock()
	if len(pub.msgs) != 1 {
		t.Fatalf("published %d messages, want 1", len(pub.msgs))
	}
	m := pub.msgs[0]
	if m.AccountLabel != "Work" || m.SpaceTitle != "#eng-standup" {
		t.Fatalf("message = %+v", m)
	}
	if m.Sender != "Alice" || m.Preview != "deploy looks good" {
		t.Fatalf("preview = %+v", m)
	}
	if m.ClickURL != "googlechatmulti://spaces/acct-work/spaces%2FAAA" {
		t.Fatalf("ClickURL = %q", m.ClickURL)
	}
}

func TestPushHandler_SkipsMuted(t *testing.T) {
	t.Parallel()

	inner, _ := json.Marshal(map[string]any{
		"message": map[string]any{
			"name": "spaces/AAA/messages/BBB",
			"text": "hi",
			"sender": map[string]any{
				"displayName": "Alice",
			},
			"space": map[string]any{
				"name":        "spaces/AAA",
				"displayName": "Room",
				"type":        "SPACE",
			},
		},
	})
	body, _ := json.Marshal(map[string]any{
		"message": map[string]any{
			"data": base64.StdEncoding.EncodeToString(inner),
			"attributes": map[string]string{
				"accountId": "acct-work",
			},
		},
	})

	pub := &fakePublisher{}
	policy := mutes.NewPolicy(map[string]bool{"acct-work": true}, nil, mutes.QuietHours{})
	h := pubsub.NewHandler(pub, fakeAccounts{byID: map[string]pubsub.AccountView{
		"acct-work": {ID: "acct-work", Label: "Work"},
	}}, policy, "googlechatmulti")

	req := httptest.NewRequest(http.MethodPost, "/pubsub/push", bytes.NewReader(body))
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)

	if rr.Code != http.StatusNoContent {
		t.Fatalf("status = %d", rr.Code)
	}
	pub.mu.Lock()
	defer pub.mu.Unlock()
	if len(pub.msgs) != 0 {
		t.Fatalf("expected mute to skip publish, got %d", len(pub.msgs))
	}
}

func TestPushHandler_UnknownAccountAcks(t *testing.T) {
	t.Parallel()

	inner, _ := json.Marshal(map[string]any{
		"message": map[string]any{
			"name": "spaces/Z/messages/1",
			"text": "x",
			"sender": map[string]any{
				"displayName": "A",
			},
			"space": map[string]any{
				"name":        "spaces/Z",
				"displayName": "Z",
				"type":        "SPACE",
			},
		},
	})
	body, _ := json.Marshal(map[string]any{
		"message": map[string]any{
			"data": base64.StdEncoding.EncodeToString(inner),
			"attributes": map[string]string{
				"accountId": "gone",
			},
		},
	})

	pub := &fakePublisher{}
	h := pubsub.NewHandler(pub, fakeAccounts{byID: map[string]pubsub.AccountView{}}, mutes.NewPolicy(nil, nil, mutes.QuietHours{}), "googlechatmulti")
	req := httptest.NewRequest(http.MethodPost, "/pubsub/push", bytes.NewReader(body))
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("status = %d", rr.Code)
	}
	if len(pub.msgs) != 0 {
		t.Fatal("should not publish for unknown account")
	}
}
