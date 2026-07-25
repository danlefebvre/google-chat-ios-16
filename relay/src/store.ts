import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import type { AccountRecord, QuietHours } from "./types.js";

export interface AccountStore {
  upsertAccount(account: AccountRecord): void;
  getAccount(accountId: string): AccountRecord | undefined;
  /** Match a Workspace Events subscription resource name to a linked account. */
  getAccountBySubscription(subscriptionName: string): AccountRecord | undefined;
  listAccounts(): AccountRecord[];
  deleteAccount(accountId: string): void;
  getQuietHours(): QuietHours | null;
  setQuietHours(quiet: QuietHours | null): void;
  /** Bark home-screen badge counter (absolute value sent on each push). */
  getBadgeCount(): number;
  /** Increment and return the new badge count. */
  incrementBadgeCount(): number;
  resetBadgeCount(): void;
}

/** Normalize `//workspaceevents.googleapis.com/subscriptions/X` → `subscriptions/X`. */
export function normalizeSubscriptionName(raw: string): string {
  const trimmed = raw.trim();
  const marker = "/subscriptions/";
  const idx = trimmed.lastIndexOf(marker);
  if (idx >= 0) {
    return `subscriptions/${trimmed.slice(idx + marker.length)}`;
  }
  if (trimmed.startsWith("subscriptions/")) {
    return trimmed;
  }
  return trimmed;
}

type PersistedState = {
  accounts: AccountRecord[];
  quietHours: QuietHours | null;
  badgeCount?: number;
};

export class InMemoryStore implements AccountStore {
  private accounts = new Map<string, AccountRecord>();
  private quietHours: QuietHours | null = null;
  private badgeCount = 0;

  upsertAccount(account: AccountRecord): void {
    this.accounts.set(account.accountId, { ...account });
  }

  getAccount(accountId: string): AccountRecord | undefined {
    const found = this.accounts.get(accountId);
    return found ? { ...found } : undefined;
  }

  getAccountBySubscription(subscriptionName: string): AccountRecord | undefined {
    const want = normalizeSubscriptionName(subscriptionName);
    for (const account of this.accounts.values()) {
      if (
        account.subscriptionName &&
        normalizeSubscriptionName(account.subscriptionName) === want
      ) {
        return { ...account };
      }
    }
    return undefined;
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

  getBadgeCount(): number {
    return this.badgeCount;
  }

  incrementBadgeCount(): number {
    this.badgeCount += 1;
    return this.badgeCount;
  }

  resetBadgeCount(): void {
    this.badgeCount = 0;
  }
}

/** JSON file-backed store so linked accounts survive process restarts. */
export class FileAccountStore implements AccountStore {
  private accounts = new Map<string, AccountRecord>();
  private quietHours: QuietHours | null = null;
  private badgeCount = 0;

  constructor(private readonly filePath: string) {
    this.load();
  }

  upsertAccount(account: AccountRecord): void {
    this.accounts.set(account.accountId, { ...account });
    this.persist();
  }

  getAccount(accountId: string): AccountRecord | undefined {
    const found = this.accounts.get(accountId);
    return found ? { ...found } : undefined;
  }

  getAccountBySubscription(subscriptionName: string): AccountRecord | undefined {
    const want = normalizeSubscriptionName(subscriptionName);
    for (const account of this.accounts.values()) {
      if (
        account.subscriptionName &&
        normalizeSubscriptionName(account.subscriptionName) === want
      ) {
        return { ...account };
      }
    }
    return undefined;
  }

  listAccounts(): AccountRecord[] {
    return [...this.accounts.values()].map((a) => ({ ...a }));
  }

  deleteAccount(accountId: string): void {
    this.accounts.delete(accountId);
    this.persist();
  }

  getQuietHours(): QuietHours | null {
    return this.quietHours ? { ...this.quietHours } : null;
  }

  setQuietHours(quiet: QuietHours | null): void {
    this.quietHours = quiet ? { ...quiet } : null;
    this.persist();
  }

  getBadgeCount(): number {
    return this.badgeCount;
  }

  incrementBadgeCount(): number {
    this.badgeCount += 1;
    this.persist();
    return this.badgeCount;
  }

  resetBadgeCount(): void {
    this.badgeCount = 0;
    this.persist();
  }

  private load(): void {
    if (!existsSync(this.filePath)) {
      return;
    }
    try {
      const raw = readFileSync(this.filePath, "utf8");
      const parsed = JSON.parse(raw) as PersistedState;
      for (const account of parsed.accounts ?? []) {
        this.accounts.set(account.accountId, account);
      }
      this.quietHours = parsed.quietHours ?? null;
      this.badgeCount =
        typeof parsed.badgeCount === "number" && parsed.badgeCount > 0
          ? Math.floor(parsed.badgeCount)
          : 0;
    } catch (err) {
      console.error("failed to load account store", this.filePath, err);
    }
  }

  private persist(): void {
    const state: PersistedState = {
      accounts: this.listAccounts(),
      quietHours: this.getQuietHours(),
      badgeCount: this.badgeCount,
    };
    const directory = dirname(this.filePath);
    mkdirSync(directory, { recursive: true });
    const tempPath = join(
      directory,
      `.${Date.now()}-${process.pid}-${Math.random().toString(16).slice(2)}.tmp`,
    );
    writeFileSync(tempPath, `${JSON.stringify(state, null, 2)}\n`, "utf8");
    renameSync(tempPath, this.filePath);
  }
}
