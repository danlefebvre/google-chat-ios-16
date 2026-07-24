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
  listAccounts(): AccountRecord[];
  deleteAccount(accountId: string): void;
  getQuietHours(): QuietHours | null;
  setQuietHours(quiet: QuietHours | null): void;
}

type PersistedState = {
  accounts: AccountRecord[];
  quietHours: QuietHours | null;
};

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

/** JSON file-backed store so linked accounts survive process restarts. */
export class FileAccountStore implements AccountStore {
  private accounts = new Map<string, AccountRecord>();
  private quietHours: QuietHours | null = null;

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
    } catch (err) {
      console.error("failed to load account store", this.filePath, err);
    }
  }

  private persist(): void {
    const state: PersistedState = {
      accounts: this.listAccounts(),
      quietHours: this.getQuietHours(),
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
