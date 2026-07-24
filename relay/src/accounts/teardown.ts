import type { AccountStore } from "./store.js";

type TeardownDeps = {
  store: AccountStore;
  accountId: string;
  deleteSubscription: (name: string) => Promise<void>;
  revokeToken: (refreshToken: string) => Promise<void>;
};

export async function teardownAccount(deps: TeardownDeps): Promise<void> {
  const account = deps.store.get(deps.accountId);
  if (!account) {
    return;
  }

  if (account.subscriptionName) {
    await deps.deleteSubscription(account.subscriptionName);
  }

  if (account.refreshToken) {
    await deps.revokeToken(account.refreshToken);
  }

  deps.store.remove(deps.accountId);
}
