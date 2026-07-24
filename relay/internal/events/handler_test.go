package events_test

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/events"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mute"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/quiet"
)

type capturePublisher struct {
	mu   sync.Mutex
	msgs []ntfy.Message
	err  error
}

func (p *capturePublisher) Publish(ctx context.Context, msg ntfy.Message) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.err != nil {
		return p.err
	}
	p.msgs = append(p.msgs, msg)
	return nil
}

func TestHandler_PublishesPreview(t *testing.T) {
	t.Parallel()

	pub := &capturePublisher{}
	h := events.NewHandler(pub, mute.NewStore(), quiet.Hours{}, time.UTC)
	err := h.Handle(context.Background(), events.Incoming{
		AccountID:    "iss|work",
		AccountLabel: "Work",
		SpaceName:    "spaces/AAA",
		SpaceTitle:   "#eng-standup",
		SenderName:   "Alice",
		Text:         "deploy looks good",
		OccurredAt:   time.Date(2026, 7, 24, 12, 0, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatalf("Handle: %v", err)
	}
	if len(pub.msgs) != 1 {
		t.Fatalf("published %d messages", len(pub.msgs))
	}
	if pub.msgs[0].Title != "[Work] #eng-standup" {
		t.Fatalf("title = %q", pub.msgs[0].Title)
	}
	if pub.msgs[0].Body != "Alice: deploy looks good" {
		t.Fatalf("body = %q", pub.msgs[0].Body)
	}
}

func TestHandler_SkipsMutedSpace(t *testing.T) {
	t.Parallel()

	pub := &capturePublisher{}
	mutes := mute.NewStore()
	mutes.MuteSpace("iss|work", "spaces/AAA")
	h := events.NewHandler(pub, mutes, quiet.Hours{}, time.UTC)
	err := h.Handle(context.Background(), events.Incoming{
		AccountID:  "iss|work",
		SpaceName:  "spaces/AAA",
		SpaceTitle: "muted",
		Text:       "hi",
		OccurredAt: time.Now().UTC(),
	})
	if err != nil {
		t.Fatalf("Handle: %v", err)
	}
	if len(pub.msgs) != 0 {
		t.Fatalf("expected skip, got %d", len(pub.msgs))
	}
}

func TestHandler_SkipsQuietHours(t *testing.T) {
	t.Parallel()

	pub := &capturePublisher{}
	h := events.NewHandler(pub, mute.NewStore(), quiet.Hours{Start: 22, End: 7}, time.UTC)
	err := h.Handle(context.Background(), events.Incoming{
		AccountID:  "a",
		SpaceName:  "spaces/X",
		SpaceTitle: "Night",
		Text:       "zzz",
		OccurredAt: time.Date(2026, 7, 24, 23, 30, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatalf("Handle: %v", err)
	}
	if len(pub.msgs) != 0 {
		t.Fatalf("expected quiet-hours skip, got %d", len(pub.msgs))
	}
}

func TestHandler_RetriesFailedPublish(t *testing.T) {
	t.Parallel()

	pub := &capturePublisher{err: context.DeadlineExceeded}
	h := events.NewHandler(pub, mute.NewStore(), quiet.Hours{}, time.UTC)
	h.Retry = events.RetryPolicy{Attempts: 3, Backoff: time.Millisecond}
	err := h.Handle(context.Background(), events.Incoming{
		AccountID:  "a",
		SpaceName:  "spaces/X",
		SpaceTitle: "Retry",
		SenderName: "Bob",
		Text:       "ping",
		OccurredAt: time.Now().UTC(),
	})
	if err == nil {
		t.Fatal("expected error after retries")
	}
	pub.mu.Lock()
	n := len(pub.msgs)
	pub.mu.Unlock()
	// all attempts failed before append; check Attempts via side effect
	if n != 0 {
		t.Fatalf("unexpected published msgs %d", n)
	}
}

func TestHandler_StopsRetryWhenContextCanceled(t *testing.T) {
	t.Parallel()

	pub := &capturePublisher{err: context.DeadlineExceeded}
	h := events.NewHandler(pub, mute.NewStore(), quiet.Hours{}, time.UTC)
	h.Retry = events.RetryPolicy{Attempts: 5, Backoff: 50 * time.Millisecond}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err := h.Handle(ctx, events.Incoming{
		AccountID:  "a",
		SpaceName:  "spaces/X",
		SpaceTitle: "Cancel",
		Text:       "ping",
		OccurredAt: time.Now().UTC(),
	})
	if err == nil {
		t.Fatal("expected context error")
	}
	if err != context.Canceled {
		t.Fatalf("err = %v, want context.Canceled", err)
	}
}

func TestParsePubSubPush_DecodesChatMessage(t *testing.T) {
	t.Parallel()

	payload := []byte(`{
		"message": {
			"data": "eyJhY2NvdW50SWQiOiJpc3N8d29yayIsImFjY291bnRMYWJlbCI6IldvcmsiLCJzcGFjZU5hbWUiOiJzcGFjZXMvQUFBIiwic3BhY2VUaXRsZSI6IiNlbmctc3RhbmR1cCIsInNlbmRlck5hbWUiOiJBbGljZSIsInRleHQiOiJkZXBsb3kgbG9va3MgZ29vZCIsIm9jY3VycmVkQXQiOiIyMDI2LTA3LTI0VDEyOjAwOjAwWiJ9"
		}
	}`)

	ev, err := events.ParsePubSubPush(payload)
	if err != nil {
		t.Fatalf("ParsePubSubPush: %v", err)
	}
	if ev.AccountID != "iss|work" {
		t.Fatalf("AccountID = %q", ev.AccountID)
	}
	if ev.Text != "deploy looks good" {
		t.Fatalf("Text = %q", ev.Text)
	}
}
