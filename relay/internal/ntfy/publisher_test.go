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

func TestPublish_SendsPreviewToTopic(t *testing.T) {
	t.Parallel()

	var gotMethod, gotPath, gotAuth, gotTitle, gotBody, gotTags string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotMethod = r.Method
		gotPath = r.URL.Path
		gotAuth = r.Header.Get("Authorization")
		gotTitle = r.Header.Get("Title")
		gotTags = r.Header.Get("Tags")
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		w.WriteHeader(http.StatusOK)
	}))
	t.Cleanup(server.Close)

	client := ntfy.NewClient(server.URL, "secret-topic", "test-token", server.Client())
	err := client.Publish(context.Background(), ntfy.Message{
		AccountLabel: "Work",
		SpaceTitle:   "#eng-standup",
		Sender:       "Alice",
		Preview:      "deploy looks good",
		ClickURL:     "googlechatmulti://spaces/spaces%2Fabc",
	})
	if err != nil {
		t.Fatalf("Publish returned error: %v", err)
	}

	if gotMethod != http.MethodPost {
		t.Fatalf("method = %q, want POST", gotMethod)
	}
	if gotPath != "/secret-topic" {
		t.Fatalf("path = %q, want /secret-topic", gotPath)
	}
	if gotAuth != "Bearer test-token" {
		t.Fatalf("Authorization = %q, want Bearer test-token", gotAuth)
	}
	if gotTitle != "[Work] #eng-standup" {
		t.Fatalf("Title = %q, want [Work] #eng-standup", gotTitle)
	}
	if gotBody != "Alice: deploy looks good" {
		t.Fatalf("body = %q, want Alice: deploy looks good", gotBody)
	}
	if !strings.Contains(gotTags, "speech_balloon") {
		t.Fatalf("Tags = %q, want speech_balloon", gotTags)
	}
}

func TestPublish_TruncatesLongPreview(t *testing.T) {
	t.Parallel()

	var gotBody string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		w.WriteHeader(http.StatusOK)
	}))
	t.Cleanup(server.Close)

	long := strings.Repeat("x", 500)
	client := ntfy.NewClient(server.URL, "topic", "", server.Client())
	if err := client.Publish(context.Background(), ntfy.Message{
		AccountLabel: "Personal",
		SpaceTitle:   "Family",
		Sender:       "Mom",
		Preview:      long,
	}); err != nil {
		t.Fatalf("Publish returned error: %v", err)
	}

	if !strings.HasPrefix(gotBody, "Mom: ") {
		t.Fatalf("body missing sender prefix: %q", gotBody)
	}
	if len(gotBody) > 280 {
		t.Fatalf("body length %d, want <= 280", len(gotBody))
	}
	if !strings.HasSuffix(gotBody, "…") {
		t.Fatalf("expected truncation ellipsis, got %q", gotBody)
	}
}

func TestPublish_PropagatesHTTPError(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
		_, _ = w.Write([]byte("rate limited"))
	}))
	t.Cleanup(server.Close)

	client := ntfy.NewClient(server.URL, "topic", "", server.Client())
	err := client.Publish(context.Background(), ntfy.Message{
		AccountLabel: "Work",
		SpaceTitle:   "space",
		Sender:       "Bob",
		Preview:      "hi",
	})
	if err == nil {
		t.Fatal("expected error for 429 response")
	}
	if !strings.Contains(err.Error(), "429") {
		t.Fatalf("error %q should mention status 429", err)
	}
}

func TestFormatTitleAndBody(t *testing.T) {
	t.Parallel()

	title, body := ntfy.FormatPreview("Home", "Family", "Mom", "dinner at 7?")
	if title != "[Home] Family" {
		t.Fatalf("title = %q", title)
	}
	if body != "Mom: dinner at 7?" {
		t.Fatalf("body = %q", body)
	}
}

func TestFormatPreview_StripsHeaderControlChars(t *testing.T) {
	t.Parallel()

	title, _ := ntfy.FormatPreview("Work\r\nX-Injected: 1", "space\ntitle", "Alice", "hi")
	if strings.ContainsAny(title, "\r\n") {
		t.Fatalf("title still contains control chars: %q", title)
	}
	if title != "[WorkX-Injected: 1] spacetitle" {
		t.Fatalf("title = %q", title)
	}
}
