import type { RelayAccount } from "./types.js";

export interface AccountStore {
  get(accountId: string): Promise<RelayAccount | undefined>;
  list(): Promise<RelayAccount[]>;
  upsert(account: RelayAccount): Promise<void>;
  remove(accountId: string): Promise<void>;
}

export class InMemoryAccountStore implements AccountStore {
  private accounts = new Map<string, RelayAccount>();

  async get(accountId: string): Promise<RelayAccount | undefined> {
    return this.accounts.get(accountId);
  }

  async list(): Promise<RelayAccount[]> {
    return Array.from(this.accounts.values());
  }

  async upsert(account: RelayAccount): Promise<void> {
    this.accounts.set(account.accountId, account);
  }

  async remove(accountId: string): Promise<void> {
    this.accounts.delete(accountId);
  }
}
