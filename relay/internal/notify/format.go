package notify

import (
	"strings"
	"unicode/utf8"
)

const maxBodyRunes = 240

// Event is a Chat message event to turn into an ntfy preview.
type Event struct {
	AccountLabel string
	SpaceTitle   string
	SenderName   string
	Text         string
	SpaceName    string
	AccountID    string
}

// Preview is the formatted ntfy title/body.
type Preview struct {
	Title    string
	Body     string
	ClickURL string
}

// FormatPreview builds title "[Account] space" and body "Sender: truncated text".
func FormatPreview(ev Event) Preview {
	label := strings.TrimSpace(ev.AccountLabel)
	if label == "" {
		label = "Account"
	}
	space := strings.TrimSpace(ev.SpaceTitle)
	if space == "" {
		space = "Chat"
	}
	sender := strings.TrimSpace(ev.SenderName)
	if sender == "" {
		sender = "Someone"
	}
	text := strings.TrimSpace(ev.Text)
	text = truncateRunes(text, maxBodyRunes)

	preview := Preview{
		Title: "[" + label + "] " + space,
		Body:  sender + ": " + text,
	}
	if ev.AccountID != "" && ev.SpaceName != "" {
		preview.ClickURL = "googlechatmulti://open?accountId=" + urlQueryEscape(ev.AccountID) + "&space=" + urlQueryEscape(ev.SpaceName)
	}
	return preview
}

func truncateRunes(s string, max int) string {
	if max <= 0 {
		return ""
	}
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	runes := []rune(s)
	if max == 1 {
		return "…"
	}
	return string(runes[:max-1]) + "…"
}

func urlQueryEscape(s string) string {
	replacer := strings.NewReplacer(
		" ", "%20",
		"&", "%26",
		"=", "%3D",
		"?", "%3F",
		"#", "%23",
	)
	return replacer.Replace(s)
}
