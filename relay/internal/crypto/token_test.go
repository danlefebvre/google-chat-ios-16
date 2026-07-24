package crypto_test

import (
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/crypto"
)

func TestEncryptDecryptRoundTrip(t *testing.T) {
	t.Parallel()
	key := []byte("0123456789abcdef0123456789abcdef") // 32 bytes
	box, err := crypto.NewTokenBox(key)
	if err != nil {
		t.Fatalf("NewTokenBox: %v", err)
	}
	ct, err := box.Encrypt("refresh-token-secret")
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}
	if ct == "refresh-token-secret" {
		t.Fatal("ciphertext should differ from plaintext")
	}
	pt, err := box.Decrypt(ct)
	if err != nil {
		t.Fatalf("Decrypt: %v", err)
	}
	if pt != "refresh-token-secret" {
		t.Fatalf("plaintext = %q", pt)
	}
}

func TestNewTokenBox_RejectsShortKey(t *testing.T) {
	t.Parallel()
	_, err := crypto.NewTokenBox([]byte("short"))
	if err == nil {
		t.Fatal("expected error")
	}
}
