package googleapi_test

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/googleapi"
)

func TestRevokeRefreshToken(t *testing.T) {
	t.Parallel()

	var gotBody string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		w.WriteHeader(http.StatusOK)
	}))
	t.Cleanup(srv.Close)

	client := googleapi.New(srv.URL, srv.Client())
	if err := client.RevokeRefreshToken(context.Background(), "rt-abc"); err != nil {
		t.Fatalf("RevokeRefreshToken: %v", err)
	}
	if !strings.Contains(gotBody, "token=rt-abc") {
		t.Fatalf("body = %q", gotBody)
	}
}

func TestExchangeRefreshToken(t *testing.T) {
	t.Parallel()

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/token" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		b, _ := io.ReadAll(r.Body)
		body := string(b)
		if !strings.Contains(body, "refresh_token=rt-abc") || !strings.Contains(body, "client_id=cid") {
			t.Fatalf("body = %q", body)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"access_token":"at-xyz","expires_in":3600}`))
	}))
	t.Cleanup(srv.Close)

	client := googleapi.New(srv.URL, srv.Client())
	tok, err := client.ExchangeRefreshToken(context.Background(), "cid", "csec", "rt-abc")
	if err != nil {
		t.Fatalf("ExchangeRefreshToken: %v", err)
	}
	if tok != "at-xyz" {
		t.Fatalf("token = %q", tok)
	}
}

func TestDeleteSubscription(t *testing.T) {
	t.Parallel()

	var gotAuth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		if r.Method != http.MethodDelete {
			t.Fatalf("method = %q", r.Method)
		}
		if r.URL.Path != "/v1/subscriptions/sub-1" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(srv.Close)

	client := googleapi.New("", srv.Client())
	if err := client.DeleteSubscription(context.Background(), srv.URL, "access", "subscriptions/sub-1"); err != nil {
		t.Fatalf("DeleteSubscription: %v", err)
	}
	if gotAuth != "Bearer access" {
		t.Fatalf("auth = %q", gotAuth)
	}
}
