import type { AccountBinding } from "./types.js";

export class InMemoryAccountStore {
  private accounts = new Map<string, AccountBinding>();

  get(accountId: string): AccountBinding | undefined {
    return this.accounts.get(accountId);
  }

  set(account: AccountBinding): void {
    this.accounts.set(account.accountId, account);
  }

  delete(accountId: string): void {
    this.accounts.delete(accountId);
  }

  list(): AccountBinding[] {
    return [...this.accounts.values()];
  }
}

export function parseMuteList(raw: string | undefined): Set<string> {
  if (!raw?.trim()) {
    return new Set();
  }
  return new Set(
    raw
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean),
  );
}

export function loadMutesFromEnv(
  env: Record<string, string | undefined> = process.env,
): { accounts: Set<string>; spaces: Set<string> } {
  return {
    accounts: parseMuteList(env.MUTED_ACCOUNTS),
    spaces: parseMuteList(env.MUTED_SPACES),
  };
}
