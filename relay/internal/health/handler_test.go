package health_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/health"
)

func TestHealthHandler_ReturnsOK(t *testing.T) {
	t.Parallel()

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rr := httptest.NewRecorder()
	health.Handler().ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rr.Code)
	}

	var payload map[string]string
	if err := json.Unmarshal(rr.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if payload["status"] != "ok" {
		t.Fatalf("status field = %q, want ok", payload["status"])
	}
	if payload["service"] != "google-chat-ntfy-relay" {
		t.Fatalf("service = %q", payload["service"])
	}
}
