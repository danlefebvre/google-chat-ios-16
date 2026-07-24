package events

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
)

// ChatEvent is a normalized Google Chat message-created event.
type ChatEvent struct {
	AccountID   string
	SpaceName   string
	SpaceTitle  string
	Sender      string
	Text        string
	MessageName string
}

type pushEnvelope struct {
	Message struct {
		Data       string            `json:"data"`
		Attributes map[string]string `json:"attributes"`
	} `json:"message"`
}

type workspacePayload struct {
	ChatEventData struct {
		MessageCreatedEventData struct {
			Message struct {
				Name   string `json:"name"`
				Text   string `json:"text"`
				Sender struct {
					DisplayName string `json:"displayName"`
				} `json:"sender"`
				Space struct {
					Name        string `json:"name"`
					DisplayName string `json:"displayName"`
				} `json:"space"`
			} `json:"message"`
		} `json:"messageCreatedEventData"`
	} `json:"chatEventData"`
}

// ParsePush decodes a Pub/Sub push body into a ChatEvent.
func ParsePush(raw []byte) (ChatEvent, error) {
	var env pushEnvelope
	if err := json.Unmarshal(raw, &env); err != nil {
		return ChatEvent{}, fmt.Errorf("decode push envelope: %w", err)
	}
	if env.Message.Data == "" {
		return ChatEvent{}, fmt.Errorf("missing message.data")
	}
	decoded, err := base64.StdEncoding.DecodeString(env.Message.Data)
	if err != nil {
		return ChatEvent{}, fmt.Errorf("decode message.data: %w", err)
	}
	var payload workspacePayload
	if err := json.Unmarshal(decoded, &payload); err != nil {
		return ChatEvent{}, fmt.Errorf("decode workspace payload: %w", err)
	}
	msg := payload.ChatEventData.MessageCreatedEventData.Message
	if msg.Name == "" || msg.Space.Name == "" {
		return ChatEvent{}, fmt.Errorf("incomplete chat message payload")
	}
	accountID := ""
	if env.Message.Attributes != nil {
		accountID = env.Message.Attributes["accountId"]
	}
	return ChatEvent{
		AccountID:   accountID,
		SpaceName:   msg.Space.Name,
		SpaceTitle:  msg.Space.DisplayName,
		Sender:      msg.Sender.DisplayName,
		Text:        msg.Text,
		MessageName: msg.Name,
	}, nil
}
