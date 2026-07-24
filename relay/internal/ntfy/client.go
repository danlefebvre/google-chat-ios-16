package ntfy

import (
	"fmt"
	"io"
	"net/http"
	"strings"
)

// Notification is a publish payload for ntfy.
type Notification struct {
	Title string
	Body  string
	Tags  []string
}

// Client publishes notifications to an ntfy server/topic.
type Client struct {
	baseURL    string
	topic      string
	accessToken string
	httpClient *http.Client
}

// NewClient builds an ntfy client. baseURL is typically https://ntfy.sh.
func NewClient(baseURL, topic, accessToken string, httpClient *http.Client) *Client {
	if httpClient == nil {
		httpClient = http.DefaultClient
	}
	return &Client{
		baseURL:     strings.TrimRight(baseURL, "/"),
		topic:       topic,
		accessToken: accessToken,
		httpClient:  httpClient,
	}
}

// Publish POSTs the notification body to /{topic}.
func (c *Client) Publish(n Notification) error {
	url := c.baseURL + "/" + c.topic
	req, err := http.NewRequest(http.MethodPost, url, strings.NewReader(n.Body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "text/plain; charset=utf-8")
	req.Header.Set("Title", n.Title)
	if len(n.Tags) > 0 {
		req.Header.Set("Tags", strings.Join(n.Tags, ","))
	}
	if c.accessToken != "" {
		req.Header.Set("Authorization", "Bearer "+c.accessToken)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return fmt.Errorf("ntfy publish failed: %s: %s", resp.Status, strings.TrimSpace(string(b)))
	}
	return nil
}
