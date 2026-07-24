package ntfy

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
)

// Message is a notification payload for ntfy.
type Message struct {
	Title    string
	Body     string
	Priority string
	Tags     []string
	ClickURL string
}

// Publisher posts messages to an ntfy server topic.
type Publisher struct {
	baseURL string
	topic   string
	token   string
	client  *http.Client
}

func NewPublisher(baseURL, topic, token string, client *http.Client) *Publisher {
	if client == nil {
		client = http.DefaultClient
	}
	return &Publisher{
		baseURL: strings.TrimRight(baseURL, "/"),
		topic:   topic,
		token:   token,
		client:  client,
	}
}

func (p *Publisher) Publish(ctx context.Context, msg Message) error {
	endpoint, err := url.JoinPath(p.baseURL, p.topic)
	if err != nil {
		return fmt.Errorf("ntfy url: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(msg.Body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "text/plain; charset=utf-8")
	if msg.Title != "" {
		req.Header.Set("Title", msg.Title)
	}
	if msg.Priority != "" {
		req.Header.Set("Priority", msg.Priority)
	}
	if len(msg.Tags) > 0 {
		req.Header.Set("Tags", strings.Join(msg.Tags, ","))
	}
	if msg.ClickURL != "" {
		req.Header.Set("Click", msg.ClickURL)
	}
	if p.token != "" {
		req.Header.Set("Authorization", "Bearer "+p.token)
	}

	res, err := p.client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(res.Body, 4096))
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return fmt.Errorf("ntfy publish failed: status %d: %s", res.StatusCode, strings.TrimSpace(string(body)))
	}
	return nil
}
