package notify_test

import (
	"strings"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/notify"
)

func TestFormatPreview_WorkSpace(t *testing.T) {
	t.Parallel()

	msg := notify.FormatPreview(notify.Event{
		AccountLabel: "Work",
		SpaceTitle:   "#eng-standup",
		SenderName:   "Alice",
		Text:         "deploy looks good",
	})

	if msg.Title != "[Work] #eng-standup" {
		t.Fatalf("title = %q", msg.Title)
	}
	if msg.Body != "Alice: deploy looks good" {
		t.Fatalf("body = %q", msg.Body)
	}
}

func TestFormatPreview_TruncatesLongBody(t *testing.T) {
	t.Parallel()

	long := strings.Repeat("x", 500)
	msg := notify.FormatPreview(notify.Event{
		AccountLabel: "Personal",
		SpaceTitle:   "Family",
		SenderName:   "Mom",
		Text:         long,
	})

	if !strings.HasPrefix(msg.Body, "Mom: ") {
		t.Fatalf("body prefix = %q", msg.Body)
	}
	if len(msg.Body) > 280 {
		t.Fatalf("body length = %d, want <= 280", len(msg.Body))
	}
	if !strings.HasSuffix(msg.Body, "…") {
		t.Fatalf("body should end with ellipsis: %q", msg.Body)
	}
}

func TestFormatPreview_EmptySenderUsesSomeone(t *testing.T) {
	t.Parallel()

	msg := notify.FormatPreview(notify.Event{
		AccountLabel: "Work",
		SpaceTitle:   "DM",
		Text:         "hello",
	})
	if msg.Body != "Someone: hello" {
		t.Fatalf("body = %q", msg.Body)
	}
}
