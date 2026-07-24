package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mutes"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/server"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/subscriptions"
)

func main() {
	addr := env("PORT", "8080")
	if addr[0] != ':' {
		addr = ":" + addr
	}

	ntfyBase := env("NTFY_BASE_URL", "https://ntfy.sh")
	ntfyTopic := os.Getenv("NTFY_TOPIC")
	ntfyToken := os.Getenv("NTFY_ACCESS_TOKEN")

	var publisher server.Publisher
	if ntfyTopic != "" {
		publisher = ntfy.NewClient(ntfyBase, ntfyTopic, ntfyToken, nil)
	} else {
		log.Printf("warning: NTFY_TOPIC unset; /v1/test/publish and push delivery disabled")
	}

	store := accounts.NewMemoryStore()
	rules := mutes.NewRules()
	if qh := os.Getenv("QUIET_HOURS"); qh != "" {
		start, end, err := parseQuietHours(qh)
		if err != nil {
			log.Fatalf("QUIET_HOURS: %v", err)
		}
		rules.SetQuietHours(mutes.QuietHours{
			StartMinute: start,
			EndMinute:   end,
			Location:    time.UTC,
		})
	}

	// Stub Google API until GCP credentials are wired; local/dev still serves health + test publish.
	subMgr := subscriptions.NewManager(subscriptions.StubAPI{})

	srv := server.New(server.Deps{
		Accounts:      store,
		Mutes:         rules,
		Ntfy:          publisher,
		Subscriptions: subMgr,
		Tokens:        accounts.MemoryTokenRevoker{Store: store},
	})

	log.Printf("relay listening on %s (ntfy=%s/%s)", addr, ntfyBase, ntfyTopic)
	if err := http.ListenAndServe(addr, srv.Handler()); err != nil {
		log.Fatal(err)
	}
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// parseQuietHours accepts "HH:MM-HH:MM" in UTC.
func parseQuietHours(s string) (int, int, error) {
	var sh, sm, eh, em int
	n, err := fmt.Sscanf(s, "%d:%d-%d:%d", &sh, &sm, &eh, &em)
	if err != nil || n != 4 {
		return 0, 0, fmt.Errorf("want HH:MM-HH:MM, got %q", s)
	}
	if sh < 0 || sh > 23 || eh < 0 || eh > 23 || sm < 0 || sm > 59 || em < 0 || em > 59 {
		return 0, 0, fmt.Errorf("invalid quiet hours %q", s)
	}
	return sh*60 + sm, eh*60 + em, nil
}
