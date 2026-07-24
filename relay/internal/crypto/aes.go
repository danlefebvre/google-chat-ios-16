package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
)

// MustKeyFromHex parses a 32-byte AES-256 key from hex or panics.
func MustKeyFromHex(s string) []byte {
	b, err := KeyFromHex(s)
	if err != nil {
		panic(err)
	}
	return b
}

// KeyFromHex parses a 32-byte AES-256 key from hex.
func KeyFromHex(s string) ([]byte, error) {
	b, err := hex.DecodeString(s)
	if err != nil {
		return nil, fmt.Errorf("decode key hex: %w", err)
	}
	if len(b) != 32 {
		return nil, fmt.Errorf("encryption key must be 32 bytes, got %d", len(b))
	}
	return b, nil
}

// Encrypt seals plaintext with AES-GCM; output is nonce||ciphertext.
func Encrypt(key, plaintext []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	return gcm.Seal(nonce, nonce, plaintext, nil), nil
}

// Decrypt opens AES-GCM nonce||ciphertext.
func Decrypt(key, ciphertext []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	if len(ciphertext) < gcm.NonceSize() {
		return nil, fmt.Errorf("ciphertext too short")
	}
	nonce, payload := ciphertext[:gcm.NonceSize()], ciphertext[gcm.NonceSize():]
	return gcm.Open(nil, nonce, payload, nil)
}
