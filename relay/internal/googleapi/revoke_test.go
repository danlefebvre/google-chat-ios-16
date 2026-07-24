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
