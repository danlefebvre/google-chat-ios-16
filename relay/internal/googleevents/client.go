package googleevents

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Client creates/renews/deletes Google Workspace Events subscriptions.
type Client struct {
	baseURL    string
	httpClient *http.Client
	token      string
}

// New builds a Workspace Events API client. accessToken must belong to the target Google account.
func New(accessToken string, httpClient *http.Client) *Client {
	if httpClient == nil {
		httpClient = http.DefaultClient
	}
	return &Client{
		baseURL:    "https://workspaceevents.googleapis.com/v1",
		httpClient: httpClient,
		token:      accessToken,
	}
}

// NewForTest builds a client against an arbitrary base URL (httptest).
func NewForTest(baseURL, accessToken string, httpClient *http.Client) *Client {
	c := New(accessToken, httpClient)
	c.baseURL = baseURL
	return c
}

type createRequest struct {
	TargetResource string           `json:"targetResource"`
	EventTypes     []string         `json:"eventTypes"`
	NotificationConfig notification `json:"notificationConfig"`
}

type notification struct {
	PubsubTopic string `json:"pubsubTopic"`
}

type subscriptionResponse struct {
	Name       string    `json:"name"`
	ExpireTime time.Time `json:"expireTime"`
}

// CreateChatMessageSubscription watches Chat messages for the user and fans out to Pub/Sub.
func (c *Client) CreateChatMessageSubscription(ctx context.Context, pubsubTopic string) (string, time.Time, error) {
	body := createRequest{
		TargetResource: "//cloudidentity.googleapis.com/users/me",
		EventTypes:     []string{"google.workspace.chat.message.v1.created"},
		NotificationConfig: notification{
			PubsubTopic: pubsubTopic,
		},
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return "", time.Time{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/subscriptions", bytes.NewReader(raw))
	if err != nil {
		return "", time.Time{}, err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", time.Time{}, err
	}
	defer resp.Body.Close()
	payload, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", time.Time{}, fmt.Errorf("workspace events create: %d %s", resp.StatusCode, string(payload))
	}
	var out subscriptionResponse
	if err := json.Unmarshal(payload, &out); err != nil {
		return "", time.Time{}, err
	}
	return out.Name, out.ExpireTime, nil
}

// Delete removes a subscription by resource name.
func (c *Client) Delete(ctx context.Context, subscriptionName string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, c.baseURL+"/"+subscriptionName, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return nil
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return fmt.Errorf("workspace events delete: %d %s", resp.StatusCode, string(b))
	}
	return nil
}
