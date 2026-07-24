package subscriptions

import (
	"fmt"
	"time"
)

// StubAPI is a no-op Google Workspace Events client for local development.
type StubAPI struct{}

func (StubAPI) Create(accountID, pubsubTopic string) (RemoteSubscription, error) {
	return RemoteSubscription{
		Name:       fmt.Sprintf("subscriptions/stub-%s", accountID),
		AccountID:  accountID,
		ExpireTime: time.Now().Add(7 * 24 * time.Hour),
	}, nil
}

func (StubAPI) Patch(name string, expire time.Time) (RemoteSubscription, error) {
	return RemoteSubscription{Name: name, ExpireTime: expire}, nil
}

func (StubAPI) Delete(name string) error { return nil }
