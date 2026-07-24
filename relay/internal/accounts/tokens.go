package accounts

// MemoryTokenRevoker clears the refresh token field on a MemoryStore account.
type MemoryTokenRevoker struct {
	Store Store
}

// Revoke deletes the stored refresh token for accountID (account row may remain until Delete).
func (r MemoryTokenRevoker) Revoke(accountID string) error {
	acc, ok := r.Store.Get(accountID)
	if !ok {
		return nil
	}
	acc.RefreshToken = ""
	return r.Store.Upsert(acc)
}
