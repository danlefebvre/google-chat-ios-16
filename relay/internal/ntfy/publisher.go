package ntfy

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"
)

const maxPreviewRunes = 240

// Message is a chat notification preview published to ntfy.
type Message struct {
	AccountLabel string
	SpaceTitle   string
	Sender       string
	Preview      string
	ClickURL     string
}

// Publisher publishes notification previews.
type Publisher interface {
	Publish(ctx context.Context, msg Message) error
}

// Client posts messages to an ntfy server.
type Client struct {
	baseURL string
	topic   string
	token   string
	http    *http.Client
}

// NewClient builds an ntfy publisher. baseURL should be like https://ntfy.sh (no trailing slash).
func NewClient(baseURL, topic, token string, httpClient *http.Client) *Client {
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 10 * time.Second}
	}
	return &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		topic:   topic,
		token:   token,
		http:    httpClient,
	}
}

// FormatPreview builds the ntfy title and body with message preview text.
func FormatPreview(accountLabel, spaceTitle, sender, preview string) (title, body string) {
	title = fmt.Sprintf("[%s] %s", sanitizeHeaderValue(accountLabel), sanitizeHeaderValue(spaceTitle))
	body = fmt.Sprintf("%s: %s", sender, truncateRunes(preview, maxPreviewRunes))
	return title, body
}

// Publish sends a preview notification to the configured topic.
func (c *Client) Publish(ctx context.Context, msg Message) error {
	title, body := FormatPreview(msg.AccountLabel, msg.SpaceTitle, msg.Sender, msg.Preview)
	url := fmt.Sprintf("%s/%s", c.baseURL, c.topic)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, strings.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Title", title)
	req.Header.Set("Tags", "speech_balloon")
	req.Header.Set("Content-Type", "text/plain; charset=utf-8")
	if msg.ClickURL != "" {
		req.Header.Set("Click", msg.ClickURL)
	}
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return fmt.Errorf("ntfy publish failed: status %d: %s", resp.StatusCode, strings.TrimSpace(string(b)))
	}
	return nil
}

// sanitizeHeaderValue strips CR/LF/NUL so values are safe in HTTP headers.
func sanitizeHeaderValue(s string) string {
	return strings.Map(func(r rune) rune {
		if r == '\r' || r == '\n' || r == 0 {
			return -1
		}
		return r
	}, s)
}

func truncateRunes(s string, max int) string {
	if max <= 0 {
		return ""
	}
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	var b strings.Builder
	n := 0
	for _, r := range s {
		if n >= max-1 {
			break
		}
		b.WriteRune(r)
		n++
	}
	b.WriteRune('…')
	return b.String()
}
