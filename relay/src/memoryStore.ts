import type { AccountStore, RelayAccount } from "./accounts.js";

export class InMemoryAccountStore implements AccountStore {
  private accounts = new Map<string, RelayAccount>();

  async get(id: string): Promise<RelayAccount | null> {
    return this.accounts.get(id) ?? null;
  }

  async list(): Promise<RelayAccount[]> {
    return [...this.accounts.values()];
  }

  async save(account: RelayAccount): Promise<void> {
    this.accounts.set(account.id, account);
  }

  async remove(id: string): Promise<void> {
    this.accounts.delete(id);
  }
}
