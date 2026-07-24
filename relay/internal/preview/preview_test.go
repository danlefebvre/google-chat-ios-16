package preview_test

import (
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/preview"
)

func TestFormat_TitleUsesAccountBadgeAndSpace(t *testing.T) {
	msg := preview.Message{
		AccountLabel: "Work",
		SpaceTitle:   "#eng-standup",
		Sender:       "Alice",
		Text:         "deploy looks good",
	}

	got := preview.Format(msg)

	if got.Title != "[Work] #eng-standup" {
		t.Fatalf("title = %q, want %q", got.Title, "[Work] #eng-standup")
	}
}

func TestFormat_BodyIsSenderAndText(t *testing.T) {
	msg := preview.Message{
		AccountLabel: "Personal",
		SpaceTitle:   "Family",
		Sender:       "Mom",
		Text:         "dinner at 7?",
	}

	got := preview.Format(msg)

	if got.Body != "Mom: dinner at 7?" {
		t.Fatalf("body = %q, want %q", got.Body, "Mom: dinner at 7?")
	}
}

func TestFormat_TruncatesLongBody(t *testing.T) {
	long := strings.Repeat("x", 500)
	msg := preview.Message{
		AccountLabel: "Work",
		SpaceTitle:   "space",
		Sender:       "Bob",
		Text:         long,
	}

	got := preview.Format(msg)

	if utf8.RuneCountInString(got.Body) > preview.MaxBodyLength {
		t.Fatalf("body length %d exceeds max %d", utf8.RuneCountInString(got.Body), preview.MaxBodyLength)
	}
	if !strings.HasSuffix(got.Body, "…") {
		t.Fatalf("expected truncated body to end with ellipsis, got %q", got.Body)
	}
}

func TestFormat_EmptyTextUsesPlaceholder(t *testing.T) {
	msg := preview.Message{
		AccountLabel: "Work",
		SpaceTitle:   "DM · Sam",
		Sender:       "Sam",
		Text:         "",
	}

	got := preview.Format(msg)

	if got.Body != "Sam: (attachment)" {
		t.Fatalf("body = %q, want attachment placeholder", got.Body)
	}
}
