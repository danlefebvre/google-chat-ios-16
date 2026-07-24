package ntfy_test

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
)

func TestPublish_PostsTitleAndBodyToTopic(t *testing.T) {
	var gotMethod, gotPath, gotAuth, gotTitle, gotBody, gotContentType string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotMethod = r.Method
		gotPath = r.URL.Path
		gotAuth = r.Header.Get("Authorization")
		gotTitle = r.Header.Get("Title")
		gotContentType = r.Header.Get("Content-Type")
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	client := ntfy.NewClient(srv.URL, "secret-topic", "tok-123", srv.Client())
	err := client.Publish(ntfy.Notification{
		Title: "[Work] #eng-standup",
		Body:  "Alice: deploy looks good",
		Tags:  []string{"chat"},
	})
	if err != nil {
		t.Fatalf("Publish error: %v", err)
	}

	if gotMethod != http.MethodPost {
		t.Fatalf("method = %q, want POST", gotMethod)
	}
	if gotPath != "/secret-topic" {
		t.Fatalf("path = %q, want /secret-topic", gotPath)
	}
	if gotAuth != "Bearer tok-123" {
		t.Fatalf("auth = %q, want Bearer tok-123", gotAuth)
	}
	if gotTitle != "[Work] #eng-standup" {
		t.Fatalf("title = %q", gotTitle)
	}
	if gotBody != "Alice: deploy looks good" {
		t.Fatalf("body = %q", gotBody)
	}
	if !strings.HasPrefix(gotContentType, "text/plain") {
		t.Fatalf("content-type = %q", gotContentType)
	}
}

func TestPublish_OmitsAuthWhenTokenEmpty(t *testing.T) {
	var gotAuth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	client := ntfy.NewClient(srv.URL, "topic", "", srv.Client())
	if err := client.Publish(ntfy.Notification{Title: "t", Body: "b"}); err != nil {
		t.Fatalf("Publish error: %v", err)
	}
	if gotAuth != "" {
		t.Fatalf("expected no auth header, got %q", gotAuth)
	}
}

func TestPublish_ReturnsErrorOnNon2xx(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer srv.Close()

	client := ntfy.NewClient(srv.URL, "topic", "", srv.Client())
	err := client.Publish(ntfy.Notification{Title: "t", Body: "b"})
	if err == nil {
		t.Fatal("expected error for 429")
	}
}
