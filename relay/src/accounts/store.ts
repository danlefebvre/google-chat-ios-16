import type { QuietHours } from "../mutes/policy.js";

export type AccountRecord = {
  accountId: string;
  label: string;
  refreshToken: string;
  subscriptionName?: string;
  muted?: boolean;
  mutedSpaces?: string[];
  quietHours?: QuietHours;
};

export class AccountStore {
  private readonly accounts = new Map<string, AccountRecord>();

  upsert(record: AccountRecord): void {
    this.accounts.set(record.accountId, { ...record });
  }

  get(accountId: string): AccountRecord | undefined {
    const record = this.accounts.get(accountId);
    return record ? { ...record } : undefined;
  }

  list(): AccountRecord[] {
    return [...this.accounts.values()].map((record) => ({ ...record }));
  }

  remove(accountId: string): void {
    this.accounts.delete(accountId);
  }
}
