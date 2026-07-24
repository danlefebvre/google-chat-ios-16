package subscriptions_test

import (
	"errors"
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/subscriptions"
)

func TestManager_CreateTracksExpiry(t *testing.T) {
	api := &fakeAPI{
		createResp: subscriptions.RemoteSubscription{
			Name:       "subscriptions/sub-1",
			ExpireTime: time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC),
		},
	}
	mgr := subscriptions.NewManager(api)
	sub, err := mgr.Ensure("issuer|sub-1", "projects/p/topics/t")
	if err != nil {
		t.Fatalf("Ensure: %v", err)
	}
	if sub.Name != "subscriptions/sub-1" {
		t.Fatalf("name = %q", sub.Name)
	}
	if api.createCalls != 1 {
		t.Fatalf("createCalls = %d", api.createCalls)
	}
}

func TestManager_RefreshBeforeExpiry(t *testing.T) {
	now := time.Date(2026, 7, 24, 12, 0, 0, 0, time.UTC)
	api := &fakeAPI{
		createResp: subscriptions.RemoteSubscription{
			Name:       "subscriptions/sub-1",
			ExpireTime: now.Add(2 * time.Hour),
		},
		patchResp: subscriptions.RemoteSubscription{
			Name:       "subscriptions/sub-1",
			ExpireTime: now.Add(48 * time.Hour),
		},
	}
	mgr := subscriptions.NewManager(api)
	mgr.Now = func() time.Time { return now }
	mgr.RefreshLead = 6 * time.Hour

	_, err := mgr.Ensure("issuer|sub-1", "projects/p/topics/t")
	if err != nil {
		t.Fatalf("Ensure: %v", err)
	}
	refreshed, err := mgr.RefreshDue()
	if err != nil {
		t.Fatalf("RefreshDue: %v", err)
	}
	if refreshed != 1 {
		t.Fatalf("refreshed = %d, want 1", refreshed)
	}
	if api.patchCalls != 1 {
		t.Fatalf("patchCalls = %d", api.patchCalls)
	}
}

func TestManager_Delete(t *testing.T) {
	api := &fakeAPI{
		createResp: subscriptions.RemoteSubscription{
			Name:       "subscriptions/sub-1",
			ExpireTime: time.Now().Add(24 * time.Hour),
		},
	}
	mgr := subscriptions.NewManager(api)
	_, _ = mgr.Ensure("issuer|sub-1", "projects/p/topics/t")
	if err := mgr.DeleteSubscription("subscriptions/sub-1"); err != nil {
		t.Fatalf("DeleteSubscription: %v", err)
	}
	if api.deleteCalls != 1 {
		t.Fatalf("deleteCalls = %d", api.deleteCalls)
	}
}

func TestManager_RefreshErrorSurfaces(t *testing.T) {
	now := time.Date(2026, 7, 24, 12, 0, 0, 0, time.UTC)
	api := &fakeAPI{
		createResp: subscriptions.RemoteSubscription{
			Name:       "subscriptions/sub-1",
			ExpireTime: now.Add(time.Hour),
		},
		patchErr: errors.New("boom"),
	}
	mgr := subscriptions.NewManager(api)
	mgr.Now = func() time.Time { return now }
	mgr.RefreshLead = 6 * time.Hour
	_, _ = mgr.Ensure("issuer|sub-1", "projects/p/topics/t")
	_, err := mgr.RefreshDue()
	if err == nil {
		t.Fatal("expected refresh error")
	}
}

type fakeAPI struct {
	createResp  subscriptions.RemoteSubscription
	patchResp   subscriptions.RemoteSubscription
	createCalls int
	patchCalls  int
	deleteCalls int
	patchErr    error
}

func (f *fakeAPI) Create(accountID, topic string) (subscriptions.RemoteSubscription, error) {
	f.createCalls++
	return f.createResp, nil
}

func (f *fakeAPI) Patch(name string, expire time.Time) (subscriptions.RemoteSubscription, error) {
	f.patchCalls++
	if f.patchErr != nil {
		return subscriptions.RemoteSubscription{}, f.patchErr
	}
	if f.patchResp.Name == "" {
		f.patchResp = subscriptions.RemoteSubscription{Name: name, ExpireTime: expire}
	}
	return f.patchResp, nil
}

func (f *fakeAPI) Delete(name string) error {
	f.deleteCalls++
	return nil
}
