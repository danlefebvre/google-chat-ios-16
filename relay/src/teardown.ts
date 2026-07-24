import type { AccountBinding } from "./types.js";

export interface AccountStore {
  get(accountId: string): AccountBinding | undefined;
  delete(accountId: string): void;
}

export interface TeardownDeps {
  deleteWorkspaceSubscription: (subscriptionName: string) => Promise<void>;
  revokeRefreshToken: (refreshToken: string) => Promise<void>;
  invalidateNtfyBinding: (accountId: string) => Promise<void>;
}

/**
 * Account-removal teardown per PLAN.md:
 * 1. Delete Workspace Events subscription
 * 2. Revoke/delete refresh token
 * 3. Invalidate ntfy binding
 * 4. Remove from local store (device wipe is client-side)
 */
export async function teardownAccount(
  store: AccountStore,
  deps: TeardownDeps,
  accountId: string,
): Promise<void> {
  const account = store.get(accountId);
  if (!account) {
    throw new Error(`Account not found: ${accountId}`);
  }

  await deps.deleteWorkspaceSubscription(account.subscriptionName);
  await deps.revokeRefreshToken(account.refreshToken);
  await deps.invalidateNtfyBinding(accountId);
  store.delete(accountId);
}
