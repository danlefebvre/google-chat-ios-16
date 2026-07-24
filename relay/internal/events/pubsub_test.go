package events_test

import (
	"encoding/base64"
	"encoding/json"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/events"
)

func TestParsePush_ExtractsChatMessageFields(t *testing.T) {
	payload := map[string]any{
		"message": map[string]any{
			"data": base64.StdEncoding.EncodeToString([]byte(`{
				"chatEventData": {
					"messageCreatedEventData": {
						"message": {
							"name": "spaces/AAA/messages/BBB",
							"sender": {"displayName": "Alice"},
							"text": "deploy looks good",
							"space": {"name": "spaces/AAA", "displayName": "#eng-standup"}
						}
					}
				}
			}`)),
			"attributes": map[string]string{
				"accountId": "issuer|sub-work",
			},
		},
	}
	raw, _ := json.Marshal(payload)

	ev, err := events.ParsePush(raw)
	if err != nil {
		t.Fatalf("ParsePush error: %v", err)
	}
	if ev.AccountID != "issuer|sub-work" {
		t.Fatalf("AccountID = %q", ev.AccountID)
	}
	if ev.SpaceName != "spaces/AAA" {
		t.Fatalf("SpaceName = %q", ev.SpaceName)
	}
	if ev.SpaceTitle != "#eng-standup" {
		t.Fatalf("SpaceTitle = %q", ev.SpaceTitle)
	}
	if ev.Sender != "Alice" {
		t.Fatalf("Sender = %q", ev.Sender)
	}
	if ev.Text != "deploy looks good" {
		t.Fatalf("Text = %q", ev.Text)
	}
	if ev.MessageName != "spaces/AAA/messages/BBB" {
		t.Fatalf("MessageName = %q", ev.MessageName)
	}
}

func TestParsePush_RejectsMissingData(t *testing.T) {
	_, err := events.ParsePush([]byte(`{"message":{}}`))
	if err == nil {
		t.Fatal("expected error for missing data")
	}
}

func TestParsePush_RejectsMissingAccountID(t *testing.T) {
	payload := map[string]any{
		"message": map[string]any{
			"data": base64.StdEncoding.EncodeToString([]byte(`{
				"chatEventData": {
					"messageCreatedEventData": {
						"message": {
							"name": "spaces/AAA/messages/BBB",
							"sender": {"displayName": "Alice"},
							"text": "hi",
							"space": {"name": "spaces/AAA", "displayName": "#eng"}
						}
					}
				}
			}`)),
		},
	}
	raw, _ := json.Marshal(payload)
	_, err := events.ParsePush(raw)
	if err == nil {
		t.Fatal("expected error for missing accountId")
	}
}
