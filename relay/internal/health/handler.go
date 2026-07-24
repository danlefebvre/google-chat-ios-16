package health

import (
	"encoding/json"
	"net/http"
)

// Handler returns a simple liveness endpoint for the relay.
func Handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"status":  "ok",
			"service": "google-chat-ntfy-relay",
		})
	})
}
