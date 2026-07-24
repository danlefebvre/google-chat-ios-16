package crypto_test

import (
	"bytes"
	"testing"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/crypto"
)

func TestEncryptDecrypt_RoundTrip(t *testing.T) {
	t.Parallel()

	key := crypto.MustKeyFromHex("00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff")
	plain := []byte("super-secret-refresh-token")
	cipher, err := crypto.Encrypt(key, plain)
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}
	if bytes.Equal(cipher, plain) {
		t.Fatal("ciphertext unexpectedly equals plaintext")
	}
	out, err := crypto.Decrypt(key, cipher)
	if err != nil {
		t.Fatalf("Decrypt: %v", err)
	}
	if !bytes.Equal(out, plain) {
		t.Fatalf("round trip mismatch: %q", out)
	}
}

func TestMustKeyFromHex_RejectsBadLength(t *testing.T) {
	t.Parallel()
	defer func() {
		if recover() == nil {
			t.Fatal("expected panic for short key")
		}
	}()
	_ = crypto.MustKeyFromHex("abcd")
}
