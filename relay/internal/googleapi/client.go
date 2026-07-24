package googleapi

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
)

// Client talks to Google OAuth revoke and Workspace Events APIs.
type Client struct {
	baseURL string
	http    *http.Client
}

func New(baseURL string, httpClient *http.Client) *Client {
	if httpClient == nil {
		httpClient = http.DefaultClient
	}
	if baseURL == "" {
		baseURL = "https://oauth2.googleapis.com"
	}
	return &Client{baseURL: strings.TrimRight(baseURL, "/"), http: httpClient}
}

func (c *Client) RevokeRefreshToken(ctx context.Context, refreshToken string) error {
	endpoint := c.baseURL + "/revoke"
	form := url.Values{"token": {refreshToken}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	res, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(res.Body, 4096))
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return fmt.Errorf("revoke failed: status %d: %s", res.StatusCode, strings.TrimSpace(string(body)))
	}
	return nil
}

// DeleteSubscription deletes a Workspace Events subscription by resource name.
// eventsBaseURL should be like https://workspaceevents.googleapis.com
func (c *Client) DeleteSubscription(ctx context.Context, eventsBaseURL, accessToken, subscriptionName string) error {
	endpoint := strings.TrimRight(eventsBaseURL, "/") + "/v1/" + strings.TrimPrefix(subscriptionName, "/")
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, endpoint, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	res, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(res.Body, 4096))
	if res.StatusCode == http.StatusNotFound {
		return nil
	}
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return fmt.Errorf("delete subscription failed: status %d: %s", res.StatusCode, strings.TrimSpace(string(body)))
	}
	return nil
}
