package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/config"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/health"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mutes"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/pubsub"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/subscriptions"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	if err := os.MkdirAll(filepath.Dir(cfg.AccountsPath), 0o700); err != nil {
		log.Fatalf("accounts dir: %v", err)
	}

	store, err := accounts.Open(cfg.AccountsPath, cfg.EncryptionKey)
	if err != nil {
		log.Fatalf("accounts store: %v", err)
	}

	publisher := ntfy.NewClient(cfg.NtfyBaseURL, cfg.NtfyTopic, cfg.NtfyToken, nil)
	policy := mutes.NewPolicy(nil, nil, cfg.QuietHours)
	subMgr := subscriptions.NewManager(subscriptions.NoopClient{}, 24*time.Hour)

	lookup := pubsub.AccountStoreAdapter{GetFn: func(id string) (string, bool) {
		a, ok := store.Get(id)
		if !ok {
			return "", false
		}
		label := a.Label
		if label == "" {
			label = a.Email
		}
		return label, true
	}}

	mux := http.NewServeMux()
	mux.Handle("/healthz", health.Handler())
	mux.Handle("/pubsub/push", pubsub.NewHandler(publisher, lookup, policy, cfg.ClickScheme))
	mux.HandleFunc("/v1/test-publish", testPublishHandler(publisher))
	mux.HandleFunc("/v1/accounts", accountsHandler(store, cfg, subMgr, policy))
	mux.HandleFunc("/v1/accounts/", accountItemHandler(store, subMgr, policy))
	mux.HandleFunc("/v1/mutes", mutesHandler(policy))

	srv := &http.Server{Addr: ":" + cfg.Port, Handler: mux}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		ticker := time.NewTicker(time.Hour)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if n, err := subMgr.RefreshDue(ctx); err != nil {
					log.Printf("subscription refresh: %v", err)
					_ = publisher.Publish(ctx, ntfy.Message{
						AccountLabel: "Relay",
						SpaceTitle:   "health",
						Sender:       "relay",
						Preview:      "Workspace Events subscription renew failed: " + err.Error(),
					})
				} else if n > 0 {
					log.Printf("renewed %d subscriptions", n)
				}
			}
		}
	}()

	go func() {
		log.Printf("relay listening on :%s (ntfy %s/%s)", cfg.Port, cfg.NtfyBaseURL, cfg.NtfyTopic)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}

func testPublishHandler(publisher ntfy.Publisher) http.HandlerFunc {
	type reqBody struct {
		AccountLabel string `json:"accountLabel"`
		SpaceTitle   string `json:"spaceTitle"`
		Sender       string `json:"sender"`
		Preview      string `json:"preview"`
	}
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		var body reqBody
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if body.AccountLabel == "" {
			body.AccountLabel = "Test"
		}
		if body.SpaceTitle == "" {
			body.SpaceTitle = "manual"
		}
		if body.Sender == "" {
			body.Sender = "relay"
		}
		if body.Preview == "" {
			body.Preview = "test notification"
		}
		if err := pubsub.PublishManual(r.Context(), publisher, body.AccountLabel, body.SpaceTitle, body.Sender, body.Preview); err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func accountsHandler(store *accounts.Store, cfg config.Config, subMgr *subscriptions.Manager, policy *mutes.Policy) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			writeJSON(w, store.List())
		case http.MethodPost:
			var body struct {
				ID           string `json:"id"`
				Email        string `json:"email"`
				Label        string `json:"label"`
				RefreshToken string `json:"refreshToken"`
				NtfyTopic    string `json:"ntfyTopic"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			if body.ID == "" || body.RefreshToken == "" {
				http.Error(w, "id and refreshToken required", http.StatusBadRequest)
				return
			}
			if body.NtfyTopic == "" {
				body.NtfyTopic = cfg.NtfyTopic
			}
			if body.Label == "" {
				body.Label = body.Email
			}
			// Subscription creation is wired through Workspace Events client in deploy;
			// NoopClient assigns a placeholder id for local/dev.
			subID, exp, err := subscriptions.NoopClient{}.Create(r.Context(), body.ID, "pubsub-topic")
			if err != nil {
				http.Error(w, err.Error(), http.StatusBadGateway)
				return
			}
			acct := accounts.Account{
				ID:             body.ID,
				Email:          body.Email,
				Label:          body.Label,
				RefreshToken:   body.RefreshToken,
				SubscriptionID: subID,
				NtfyTopic:      body.NtfyTopic,
			}
			if err := store.Upsert(r.Context(), acct); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			subMgr.Track(subscriptions.Record{
				AccountID:      acct.ID,
				SubscriptionID: subID,
				ExpireTime:     exp,
			})
			w.WriteHeader(http.StatusCreated)
			writeJSON(w, map[string]string{"id": acct.ID, "subscriptionId": subID})
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	}
}

func accountItemHandler(store *accounts.Store, subMgr *subscriptions.Manager, policy *mutes.Policy) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Path[len("/v1/accounts/"):]
		if id == "" {
			http.NotFound(w, r)
			return
		}
		if r.Method != http.MethodDelete {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		hooks := accounts.TeardownHooks{
			DeleteSubscription: func(ctx context.Context, subscriptionID string) error {
				return subMgr.Delete(ctx, id)
			},
			RevokeRefreshToken: func(ctx context.Context, refreshToken string) error {
				// Token revocation against Google is optional in local/dev; always clears store.
				return nil
			},
			InvalidateNtfyBinding: func(ctx context.Context, accountID, topic string) error {
				policy.SetAccountMuted(accountID, true)
				return nil
			},
		}
		if err := store.Remove(r.Context(), id, hooks); err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func mutesHandler(policy *mutes.Policy) http.HandlerFunc {
	type reqBody struct {
		AccountID string `json:"accountId"`
		SpaceName string `json:"spaceName"`
		Muted     bool   `json:"muted"`
	}
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		var body reqBody
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if body.AccountID == "" {
			http.Error(w, "accountId required", http.StatusBadRequest)
			return
		}
		if body.SpaceName == "" {
			policy.SetAccountMuted(body.AccountID, body.Muted)
		} else {
			policy.SetSpaceMuted(body.AccountID, body.SpaceName, body.Muted)
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}
