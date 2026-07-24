package ntfy_test

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
)

func TestPublish_PostsTitleBodyAndAuth(t *testing.T) {
	t.Parallel()

	var gotMethod, gotPath, gotAuth, gotTitle, gotPriority, gotTags string
	var gotBody string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotMethod = r.Method
		gotPath = r.URL.Path
		gotAuth = r.Header.Get("Authorization")
		gotTitle = r.Header.Get("Title")
		gotPriority = r.Header.Get("Priority")
		gotTags = r.Header.Get("Tags")
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))
	t.Cleanup(srv.Close)

	pub := ntfy.NewPublisher(srv.URL, "secret-topic", "ntfy-token", srv.Client())
	err := pub.Publish(context.Background(), ntfy.Message{
		Title:    "[Work] #eng-standup",
		Body:     "Alice: deploy looks good",
		Priority: "default",
		Tags:     []string{"chat"},
		ClickURL: "googlechatmulti://spaces/AAA",
	})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}

	if gotMethod != http.MethodPost {
		t.Fatalf("method = %q, want POST", gotMethod)
	}
	if gotPath != "/secret-topic" {
		t.Fatalf("path = %q, want /secret-topic", gotPath)
	}
	if gotAuth != "Bearer ntfy-token" {
		t.Fatalf("auth = %q, want Bearer ntfy-token", gotAuth)
	}
	if gotTitle != "[Work] #eng-standup" {
		t.Fatalf("title = %q", gotTitle)
	}
	if gotBody != "Alice: deploy looks good" {
		t.Fatalf("body = %q", gotBody)
	}
	if gotPriority != "default" {
		t.Fatalf("priority = %q", gotPriority)
	}
	if !strings.Contains(gotTags, "chat") {
		t.Fatalf("tags = %q, want chat", gotTags)
	}
}

func TestPublish_OmitsAuthWhenTokenEmpty(t *testing.T) {
	t.Parallel()

	var gotAuth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusOK)
	}))
	t.Cleanup(srv.Close)

	pub := ntfy.NewPublisher(srv.URL, "topic", "", srv.Client())
	if err := pub.Publish(context.Background(), ntfy.Message{Title: "t", Body: "b"}); err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if gotAuth != "" {
		t.Fatalf("auth = %q, want empty", gotAuth)
	}
}

func TestPublish_ReturnsErrorOnNon2xx(t *testing.T) {
	t.Parallel()

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
		_, _ = w.Write([]byte("rate limited"))
	}))
	t.Cleanup(srv.Close)

	pub := ntfy.NewPublisher(srv.URL, "topic", "", srv.Client())
	err := pub.Publish(context.Background(), ntfy.Message{Title: "t", Body: "b"})
	if err == nil {
		t.Fatal("expected error")
	}
	if !strings.Contains(err.Error(), "429") {
		t.Fatalf("error = %v, want status 429", err)
	}
}
