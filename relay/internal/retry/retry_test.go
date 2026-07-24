package retry_test

import (
	"errors"
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/retry"
)

func TestDo_SucceedsFirstTry(t *testing.T) {
	calls := 0
	err := retry.Do(3, time.Millisecond, func() error {
		calls++
		return nil
	})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if calls != 1 {
		t.Fatalf("calls = %d", calls)
	}
}

func TestDo_RetriesThenSucceeds(t *testing.T) {
	calls := 0
	err := retry.Do(3, time.Millisecond, func() error {
		calls++
		if calls < 3 {
			return errors.New("transient")
		}
		return nil
	})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if calls != 3 {
		t.Fatalf("calls = %d", calls)
	}
}

func TestDo_ReturnsLastError(t *testing.T) {
	err := retry.Do(2, time.Millisecond, func() error {
		return errors.New("still failing")
	})
	if err == nil || err.Error() != "still failing" {
		t.Fatalf("err = %v", err)
	}
}
