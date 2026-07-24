import type { AccountRecord, QuietHours } from "./types.js";

export interface AccountStore {
  upsertAccount(account: AccountRecord): void;
  getAccount(accountId: string): AccountRecord | undefined;
  listAccounts(): AccountRecord[];
  deleteAccount(accountId: string): void;
  getQuietHours(): QuietHours | null;
  setQuietHours(quiet: QuietHours | null): void;
}

export class InMemoryStore implements AccountStore {
  private accounts = new Map<string, AccountRecord>();
  private quietHours: QuietHours | null = null;

  upsertAccount(account: AccountRecord): void {
    this.accounts.set(account.accountId, { ...account });
  }

  getAccount(accountId: string): AccountRecord | undefined {
    const found = this.accounts.get(accountId);
    return found ? { ...found } : undefined;
  }

  listAccounts(): AccountRecord[] {
    return [...this.accounts.values()].map((a) => ({ ...a }));
  }

  deleteAccount(accountId: string): void {
    this.accounts.delete(accountId);
  }

  getQuietHours(): QuietHours | null {
    return this.quietHours ? { ...this.quietHours } : null;
  }

  setQuietHours(quiet: QuietHours | null): void {
    this.quietHours = quiet ? { ...quiet } : null;
  }
}
