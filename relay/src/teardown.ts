import type { RelayAccount } from "./types.js";

interface TeardownDeps {
  deleteSubscription: (subscriptionName: string) => Promise<void>;
  revokeToken: (refreshToken: string) => Promise<void>;
  storeRemove: (accountId: string) => Promise<void>;
}

export async function teardownAccount(account: RelayAccount, deps: TeardownDeps): Promise<void> {
  await deps.deleteSubscription(account.subscriptionName);
  await deps.revokeToken(account.refreshToken);
  await deps.storeRemove(account.accountId);
}
