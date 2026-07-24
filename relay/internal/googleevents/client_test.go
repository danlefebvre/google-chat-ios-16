package googleevents_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/googleevents"
)

func TestCreateChatMessageSubscription(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/subscriptions" {
			t.Fatalf("path = %s", r.URL.Path)
		}
		if r.Header.Get("Authorization") != "Bearer tok" {
			t.Fatalf("auth = %s", r.Header.Get("Authorization"))
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"name":       "subscriptions/abc",
			"expireTime": time.Now().UTC().Add(7 * 24 * time.Hour).Format(time.RFC3339),
		})
	}))
	t.Cleanup(server.Close)

	client := googleevents.New("tok", server.Client())
	// Point baseURL at test server by recreating via unexported field — use New then override through helper.
	client = googleevents.NewForTest(server.URL, "tok", server.Client())
	name, exp, err := client.CreateChatMessageSubscription(context.Background(), "projects/p/topics/t")
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if name != "subscriptions/abc" {
		t.Fatalf("name = %s", name)
	}
	if exp.Before(time.Now()) {
		t.Fatalf("expireTime in past: %v", exp)
	}
}
