import type { RelayAccount } from "./types.js";

interface TeardownDeps {
  deleteSubscription: (subscriptionName: string) => Promise<void>;
  revokeToken: (refreshToken: string) => Promise<void>;
  storeRemove: (accountId: string) => Promise<void>;
}

export async function teardownAccount(account: RelayAccount, deps: TeardownDeps): Promise<void> {
  const failures: unknown[] = [];
  for (const cleanup of [
    () => deps.deleteSubscription(account.subscriptionName),
    () => deps.revokeToken(account.refreshToken),
    () => deps.storeRemove(account.accountId),
  ]) {
    try {
      await cleanup();
    } catch (error) {
      failures.push(error);
    }
  }
  if (failures.length) {
    throw new AggregateError(failures, "account teardown failed");
  }
}
