package events_test

import (
	"encoding/base64"
	"encoding/json"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/events"
)

func TestParseChatMessageCreated_ExtractsFields(t *testing.T) {
	t.Parallel()

	payload := []byte(`{
		"message": {
			"name": "spaces/AAA/messages/BBB",
			"sender": {
				"name": "users/111",
				"displayName": "Alice",
				"type": "HUMAN"
			},
			"text": "deploy looks good",
			"createTime": "2026-07-24T12:00:00Z",
			"space": {
				"name": "spaces/AAA",
				"displayName": "#eng-standup",
				"type": "SPACE"
			}
		}
	}`)

	msg, err := events.ParseChatMessageCreated(payload)
	if err != nil {
		t.Fatalf("ParseChatMessageCreated: %v", err)
	}
	if msg.SpaceName != "spaces/AAA" {
		t.Fatalf("SpaceName = %q", msg.SpaceName)
	}
	if msg.SpaceTitle != "#eng-standup" {
		t.Fatalf("SpaceTitle = %q", msg.SpaceTitle)
	}
	if msg.Sender != "Alice" {
		t.Fatalf("Sender = %q", msg.Sender)
	}
	if msg.Text != "deploy looks good" {
		t.Fatalf("Text = %q", msg.Text)
	}
	if msg.MessageName != "spaces/AAA/messages/BBB" {
		t.Fatalf("MessageName = %q", msg.MessageName)
	}
}

func TestParseChatMessageCreated_DMFallbackTitle(t *testing.T) {
	t.Parallel()

	payload := []byte(`{
		"message": {
			"name": "spaces/DM/messages/1",
			"sender": {"displayName": "Sam"},
			"text": "ping",
			"space": {"name": "spaces/DM", "type": "DIRECT_MESSAGE"}
		}
	}`)

	msg, err := events.ParseChatMessageCreated(payload)
	if err != nil {
		t.Fatalf("ParseChatMessageCreated: %v", err)
	}
	if msg.SpaceTitle != "DM · Sam" {
		t.Fatalf("SpaceTitle = %q, want DM · Sam", msg.SpaceTitle)
	}
}

func TestParsePubSubPush_UnwrapsData(t *testing.T) {
	t.Parallel()

	inner := []byte(`{"message":{"text":"hi","sender":{"displayName":"A"},"space":{"name":"spaces/X","displayName":"Room","type":"SPACE"},"name":"spaces/X/messages/Y"}}`)
	body, err := json.Marshal(map[string]any{
		"message": map[string]any{
			"data":      base64.StdEncoding.EncodeToString(inner),
			"messageId": "msg-1",
			"attributes": map[string]string{
				"accountId": "issuer|sub-123",
			},
		},
		"subscription": "projects/p/subscriptions/s",
	})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	env, err := events.ParsePubSubPush(body)
	if err != nil {
		t.Fatalf("ParsePubSubPush: %v", err)
	}
	if env.AccountID != "issuer|sub-123" {
		t.Fatalf("AccountID = %q", env.AccountID)
	}
	if env.Message.Text != "hi" {
		t.Fatalf("Text = %q", env.Message.Text)
	}
	if env.Message.SpaceTitle != "Room" {
		t.Fatalf("SpaceTitle = %q", env.Message.SpaceTitle)
	}
}
