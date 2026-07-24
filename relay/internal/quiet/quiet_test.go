package quiet_test

import (
	"testing"
	"time"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/quiet"
)

func TestInQuietHours_WrapsMidnight(t *testing.T) {
	t.Parallel()

	loc := time.FixedZone("test", -5*3600)
	qh := quiet.Hours{Start: 22, End: 7} // 10pm–7am

	at := time.Date(2026, 7, 24, 23, 0, 0, 0, loc)
	if !qh.Contains(at) {
		t.Fatal("23:00 should be quiet")
	}
	at = time.Date(2026, 7, 24, 6, 59, 0, 0, loc)
	if !qh.Contains(at) {
		t.Fatal("06:59 should be quiet")
	}
	at = time.Date(2026, 7, 24, 7, 0, 0, 0, loc)
	if qh.Contains(at) {
		t.Fatal("07:00 should not be quiet")
	}
	at = time.Date(2026, 7, 24, 12, 0, 0, 0, loc)
	if qh.Contains(at) {
		t.Fatal("noon should not be quiet")
	}
}

func TestInQuietHours_SameDayWindow(t *testing.T) {
	t.Parallel()

	loc := time.UTC
	qh := quiet.Hours{Start: 13, End: 14}
	at := time.Date(2026, 7, 24, 13, 30, 0, 0, loc)
	if !qh.Contains(at) {
		t.Fatal("13:30 should be quiet")
	}
	at = time.Date(2026, 7, 24, 14, 0, 0, 0, loc)
	if qh.Contains(at) {
		t.Fatal("14:00 should not be quiet")
	}
}

func TestDisabledWhenStartEqualsEnd(t *testing.T) {
	t.Parallel()
	qh := quiet.Hours{Start: 0, End: 0}
	at := time.Date(2026, 7, 24, 3, 0, 0, 0, time.UTC)
	if qh.Contains(at) {
		t.Fatal("disabled quiet hours should never contain")
	}
}
