package events

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
)

// ChatMessage is a normalized Google Chat message event.
type ChatMessage struct {
	MessageName string
	SpaceName   string
	SpaceTitle  string
	Sender      string
	Text        string
	SpaceType   string
}

// PubSubMessage is the inner Pub/Sub push message envelope.
type PubSubMessage struct {
	Data       string            `json:"data"`
	MessageID  string            `json:"messageId"`
	Attributes map[string]string `json:"attributes"`
}

// PubSubPush is a Cloud Pub/Sub push body.
type PubSubPush struct {
	Message      PubSubMessage `json:"message"`
	Subscription string        `json:"subscription"`
}

// Envelope is a decoded push with account binding.
type Envelope struct {
	AccountID string
	Message   ChatMessage
}

type rawChatPayload struct {
	Message struct {
		Name   string `json:"name"`
		Text   string `json:"text"`
		Sender struct {
			DisplayName string `json:"displayName"`
		} `json:"sender"`
		Space struct {
			Name        string `json:"name"`
			DisplayName string `json:"displayName"`
			Type        string `json:"type"`
		} `json:"space"`
	} `json:"message"`
}

// ParseChatMessageCreated extracts fields from a Chat message-created payload.
func ParseChatMessageCreated(payload []byte) (ChatMessage, error) {
	var raw rawChatPayload
	if err := json.Unmarshal(payload, &raw); err != nil {
		return ChatMessage{}, fmt.Errorf("decode chat payload: %w", err)
	}
	msg := ChatMessage{
		MessageName: raw.Message.Name,
		SpaceName:   raw.Message.Space.Name,
		SpaceTitle:  raw.Message.Space.DisplayName,
		Sender:      raw.Message.Sender.DisplayName,
		Text:        raw.Message.Text,
		SpaceType:   raw.Message.Space.Type,
	}
	if msg.SpaceTitle == "" && strings.EqualFold(msg.SpaceType, "DIRECT_MESSAGE") {
		msg.SpaceTitle = "DM · " + msg.Sender
	}
	if msg.SpaceName == "" {
		return ChatMessage{}, fmt.Errorf("chat payload missing space name")
	}
	return msg, nil
}

// ParsePubSubPush unwraps a Pub/Sub push body into a chat envelope.
func ParsePubSubPush(body []byte) (Envelope, error) {
	var push PubSubPush
	if err := json.Unmarshal(body, &push); err != nil {
		return Envelope{}, fmt.Errorf("decode pubsub push: %w", err)
	}
	if push.Message.Data == "" {
		return Envelope{}, fmt.Errorf("pubsub message missing data")
	}
	decoded, err := base64.StdEncoding.DecodeString(push.Message.Data)
	if err != nil {
		return Envelope{}, fmt.Errorf("decode pubsub data: %w", err)
	}
	msg, err := ParseChatMessageCreated(decoded)
	if err != nil {
		return Envelope{}, err
	}
	accountID := ""
	if push.Message.Attributes != nil {
		accountID = push.Message.Attributes["accountId"]
	}
	return Envelope{AccountID: accountID, Message: msg}, nil
}
