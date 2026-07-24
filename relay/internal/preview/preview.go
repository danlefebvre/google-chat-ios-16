package preview

import "unicode/utf8"

// MaxBodyLength is the max ntfy body size we emit (sender + text).
const MaxBodyLength = 200

// Message is the input for building an ntfy preview.
type Message struct {
	AccountLabel string
	SpaceTitle   string
	Sender       string
	Text         string
}

// Notification is a formatted title/body pair for ntfy.
type Notification struct {
	Title string
	Body  string
}

// Format builds title "[Account] space" and body "Sender: text".
func Format(msg Message) Notification {
	text := msg.Text
	if text == "" {
		text = "(attachment)"
	}
	body := msg.Sender + ": " + text
	if utf8.RuneCountInString(body) > MaxBodyLength {
		runes := []rune(body)
		body = string(runes[:MaxBodyLength-1]) + "…"
	}
	return Notification{
		Title: "[" + msg.AccountLabel + "] " + msg.SpaceTitle,
		Body:  body,
	}
}
