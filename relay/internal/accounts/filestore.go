package accounts

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"github.com/danlefebvre/google-chat-ios-16/relay/internal/crypto"
)

// FileStore persists account bindings as JSON with AES-GCM–encrypted refresh tokens.
type FileStore struct {
	mu   sync.RWMutex
	path string
	box  *crypto.Box
	byID map[string]Account
}

type fileRecord struct {
	ID                    string `json:"id"`
	Email                 string `json:"email"`
	Label                 string `json:"label"`
	RefreshTokenSealedB64 string `json:"refreshTokenSealed,omitempty"`
	Subscription          string `json:"subscription"`
	NtfyTopic             string `json:"ntfyTopic"`
}

// NewFileStore loads (or creates) an encrypted JSON account store at path.
// key must be 32 bytes.
func NewFileStore(path string, key []byte) (*FileStore, error) {
	box, err := crypto.NewBox(key)
	if err != nil {
		return nil, err
	}
	s := &FileStore{
		path: path,
		box:  box,
		byID: make(map[string]Account),
	}
	if err := s.load(); err != nil {
		return nil, err
	}
	return s, nil
}

func (s *FileStore) load() error {
	data, err := os.ReadFile(s.path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	var rows []fileRecord
	if err := json.Unmarshal(data, &rows); err != nil {
		return fmt.Errorf("decode account store: %w", err)
	}
	for _, row := range rows {
		acc := Account{
			ID:           row.ID,
			Email:        row.Email,
			Label:        row.Label,
			Subscription: row.Subscription,
			NtfyTopic:    row.NtfyTopic,
		}
		if row.RefreshTokenSealedB64 != "" {
			sealed, err := base64.StdEncoding.DecodeString(row.RefreshTokenSealedB64)
			if err != nil {
				return fmt.Errorf("decode sealed token for %s: %w", row.ID, err)
			}
			pt, err := s.box.Open(sealed)
			if err != nil {
				return fmt.Errorf("decrypt token for %s: %w", row.ID, err)
			}
			acc.RefreshToken = string(pt)
		}
		s.byID[acc.ID] = acc
	}
	return nil
}

func (s *FileStore) persistLocked() error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return err
	}
	rows := make([]fileRecord, 0, len(s.byID))
	for _, acc := range s.byID {
		row := fileRecord{
			ID:           acc.ID,
			Email:        acc.Email,
			Label:        acc.Label,
			Subscription: acc.Subscription,
			NtfyTopic:    acc.NtfyTopic,
		}
		if acc.RefreshToken != "" {
			sealed, err := s.box.Seal([]byte(acc.RefreshToken))
			if err != nil {
				return err
			}
			row.RefreshTokenSealedB64 = base64.StdEncoding.EncodeToString(sealed)
		}
		rows = append(rows, row)
	}
	data, err := json.MarshalIndent(rows, "", "  ")
	if err != nil {
		return err
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, s.path)
}

func (s *FileStore) Upsert(a Account) error {
	if a.ID == "" {
		return fmt.Errorf("account id required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.byID[a.ID] = a
	return s.persistLocked()
}

func (s *FileStore) Get(id string) (Account, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.byID[id]
	return a, ok
}

func (s *FileStore) Delete(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.byID, id)
	return s.persistLocked()
}

func (s *FileStore) List() []Account {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Account, 0, len(s.byID))
	for _, a := range s.byID {
		out = append(out, a)
	}
	return out
}
