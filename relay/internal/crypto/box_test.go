package crypto_test

import (
	"bytes"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/crypto"
)

func TestSealOpen_RoundTrip(t *testing.T) {
	key := bytes.Repeat([]byte{7}, 32)
	box, err := crypto.NewBox(key)
	if err != nil {
		t.Fatalf("NewBox: %v", err)
	}
	ct, err := box.Seal([]byte("refresh-token-value"))
	if err != nil {
		t.Fatalf("Seal: %v", err)
	}
	if bytes.Equal(ct, []byte("refresh-token-value")) {
		t.Fatal("ciphertext should not equal plaintext")
	}
	pt, err := box.Open(ct)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	if string(pt) != "refresh-token-value" {
		t.Fatalf("plaintext = %q", pt)
	}
}

func TestNewBox_RejectsShortKey(t *testing.T) {
	_, err := crypto.NewBox([]byte("short"))
	if err == nil {
		t.Fatal("expected error for short key")
	}
}
