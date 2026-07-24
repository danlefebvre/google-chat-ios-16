package events

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"
)

type pubSubPushEnvelope struct {
	Message struct {
		Data string `json:"data"`
	} `json:"message"`
}

type incomingJSON struct {
	AccountID    string    `json:"accountId"`
	AccountLabel string    `json:"accountLabel"`
	SpaceName    string    `json:"spaceName"`
	SpaceTitle   string    `json:"spaceTitle"`
	SenderName   string    `json:"senderName"`
	Text         string    `json:"text"`
	OccurredAt   time.Time `json:"occurredAt"`
}

// ParsePubSubPush decodes a Pub/Sub push body whose data is base64 JSON Incoming.
func ParsePubSubPush(body []byte) (Incoming, error) {
	var env pubSubPushEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		return Incoming{}, fmt.Errorf("pubsub envelope: %w", err)
	}
	if env.Message.Data == "" {
		return Incoming{}, fmt.Errorf("pubsub message missing data")
	}
	raw, err := base64.StdEncoding.DecodeString(env.Message.Data)
	if err != nil {
		// Pub/Sub sometimes uses raw URL encoding; try that too.
		raw, err = base64.RawURLEncoding.DecodeString(env.Message.Data)
		if err != nil {
			return Incoming{}, fmt.Errorf("pubsub data decode: %w", err)
		}
	}
	var in incomingJSON
	if err := json.Unmarshal(raw, &in); err != nil {
		return Incoming{}, fmt.Errorf("pubsub data json: %w", err)
	}
	return Incoming{
		AccountID:    in.AccountID,
		AccountLabel: in.AccountLabel,
		SpaceName:    in.SpaceName,
		SpaceTitle:   in.SpaceTitle,
		SenderName:   in.SenderName,
		Text:         in.Text,
		OccurredAt:   in.OccurredAt,
	}, nil
}
