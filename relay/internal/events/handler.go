package events

import (
	"context"
	"fmt"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/mute"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/notify"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/ntfy"
	"github.com/danlefebvre/google-chat-ios-16/relay/internal/quiet"
)

// Publisher is implemented by ntfy.Publisher (and test doubles).
type Publisher interface {
	Publish(ctx context.Context, msg ntfy.Message) error
}

// Incoming is a normalized Chat message event.
type Incoming struct {
	AccountID    string
	AccountLabel string
	SpaceName    string
	SpaceTitle   string
	SenderName   string
	Text         string
	OccurredAt   time.Time
}

// RetryPolicy controls publish retries.
type RetryPolicy struct {
	Attempts int
	Backoff  time.Duration
}

// Handler turns Chat events into ntfy publishes, honoring mutes and quiet hours.
type Handler struct {
	pub    Publisher
	mutes  *mute.Store
	quiet  quiet.Hours
	loc    *time.Location
	Retry  RetryPolicy
	now    func() time.Time
	sleep  func(time.Duration)
}

func NewHandler(pub Publisher, mutes *mute.Store, qh quiet.Hours, loc *time.Location) *Handler {
	if loc == nil {
		loc = time.UTC
	}
	if mutes == nil {
		mutes = mute.NewStore()
	}
	return &Handler{
		pub:   pub,
		mutes: mutes,
		quiet: qh,
		loc:   loc,
		Retry: RetryPolicy{Attempts: 3, Backoff: 200 * time.Millisecond},
		now:   time.Now,
		sleep: time.Sleep,
	}
}

func (h *Handler) Handle(ctx context.Context, in Incoming) error {
	if !h.mutes.ShouldNotify(in.AccountID, in.SpaceName) {
		return nil
	}
	when := in.OccurredAt
	if when.IsZero() {
		when = h.now()
	}
	if h.quiet.Contains(when.In(h.loc)) {
		return nil
	}

	preview := notify.FormatPreview(notify.Event{
		AccountLabel: in.AccountLabel,
		SpaceTitle:   in.SpaceTitle,
		SenderName:   in.SenderName,
		Text:         in.Text,
		SpaceName:    in.SpaceName,
		AccountID:    in.AccountID,
	})

	msg := ntfy.Message{
		Title:    preview.Title,
		Body:     preview.Body,
		Tags:     []string{"chat"},
		ClickURL: preview.ClickURL,
		Priority: "default",
	}

	attempts := h.Retry.Attempts
	if attempts < 1 {
		attempts = 1
	}
	var lastErr error
	for i := 0; i < attempts; i++ {
		if err := h.pub.Publish(ctx, msg); err != nil {
			lastErr = err
			if i+1 < attempts {
				h.sleep(h.Retry.Backoff)
			}
			continue
		}
		return nil
	}
	return fmt.Errorf("publish after %d attempts: %w", attempts, lastErr)
}
