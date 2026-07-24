package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/accounts"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/config"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/events"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/googleapi"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/httpserver"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mute"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/subscriptions"
)

func main() {
	env := envMap()
	cfg, err := config.Load(env)
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	if cfg.NtfyTopic == "" {
		log.Printf("warning: NTFY_TOPIC empty; /v1/notify/test will fail until set")
	}
	if cfg.APIToken == "" {
		log.Printf("warning: RELAY_API_TOKEN empty; management routes are unauthenticated")
	}

	store := accounts.NewMemoryStore()
	mutes := mute.NewStore()
	pub := ntfy.NewPublisher(cfg.NtfyBaseURL, cfg.NtfyTopic, cfg.NtfyAccessToken, nil)
	handler := events.NewHandler(pub, mutes, cfg.QuietHours, cfg.QuietHoursLocation)
	gclient := googleapi.New("", nil)

	teardown := accounts.Teardown{
		Store: store,
		DeleteSubscription: func(ctx context.Context, name string) error {
			if name == "" {
				return nil
			}
			if cfg.GoogleClientID == "" || cfg.GoogleClientSecret == "" {
				return fmt.Errorf("delete subscription %s: GOOGLE_CLIENT_ID/SECRET not configured", name)
			}
			refresh := ""
			for _, acc := range store.List(ctx) {
				if acc.SubscriptionName == name {
					refresh = acc.RefreshToken
					break
				}
			}
			if refresh == "" {
				return fmt.Errorf("delete subscription %s: refresh token not found", name)
			}
			accessToken, err := gclient.ExchangeRefreshToken(ctx, cfg.GoogleClientID, cfg.GoogleClientSecret, refresh)
			if err != nil {
				return fmt.Errorf("delete subscription token exchange: %w", err)
			}
			return gclient.DeleteSubscription(ctx, cfg.EventsBaseURL, accessToken, name)
		},
		RevokeRefreshToken: func(ctx context.Context, token string) error {
			return gclient.RevokeRefreshToken(ctx, token)
		},
		ClearNtfyBinding: func(ctx context.Context, accountID string) error {
			acc, ok := store.Get(ctx, accountID)
			if !ok {
				return nil
			}
			acc.NtfyBound = false
			return store.Upsert(ctx, acc)
		},
	}

	mgr := subscriptions.Manager{
		Store:       store,
		RenewWithin: 24 * time.Hour,
		Renew: func(ctx context.Context, accountID, subscriptionName string) (string, time.Time, error) {
			// Fail closed until Workspace Events renew (LRO) is fully wired.
			return "", time.Time{}, fmt.Errorf("subscription renew not implemented for %s (%s)", accountID, subscriptionName)
		},
		OnRenewFailure: func(ctx context.Context, account accounts.Account, err error) {
			_ = pub.Publish(ctx, ntfy.Message{
				Title: "[Relay] subscription renew failed",
				Body:  account.Label + " (" + account.ID + "): " + err.Error(),
				Tags:  []string{"warning"},
			})
		},
	}

	srv := httpserver.New(httpserver.Deps{
		Accounts:          store,
		Mutes:             mutes,
		Handler:           handler,
		Publisher:         pub,
		Teardown:          teardown,
		PubSubVerifyToken: cfg.PubSubVerifyToken,
		APIToken:          cfg.APIToken,
	})

	httpSrv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           srv.Handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

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
				if err := mgr.RefreshExpiring(ctx); err != nil {
					log.Printf("subscription refresh: %v", err)
				}
			}
		}
	}()

	go func() {
		log.Printf("relay listening on %s (ntfy base=%s)", cfg.HTTPAddr, cfg.NtfyBaseURL)
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = httpSrv.Shutdown(shutdownCtx)
}

func envMap() map[string]string {
	out := map[string]string{}
	for _, e := range os.Environ() {
		for i := 0; i < len(e); i++ {
			if e[i] == '=' {
				out[e[:i]] = e[i+1:]
				break
			}
		}
	}
	return out
}
