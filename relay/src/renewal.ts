import type { AccountStore } from "./store.js";
import type { EventsClient, TokenCrypto } from "./types.js";

export type RenewResult = {
  renewed: string[];
  skipped: string[];
  failed: string[];
};

export async function renewExpiringSubscriptions(deps: {
  store: AccountStore;
  events: EventsClient;
  crypto: TokenCrypto;
  horizonMs: number;
  now?: Date;
  alertRenewFailure?: (info: {
    accountId: string;
    error: unknown;
  }) => Promise<void> | void;
}): Promise<RenewResult> {
  const now = deps.now ?? new Date();
  const renewed: string[] = [];
  const skipped: string[] = [];
  const failed: string[] = [];

  for (const account of deps.store.listAccounts()) {
    if (!account.subscriptionName || !account.subscriptionExpireTime) {
      skipped.push(account.accountId);
      continue;
    }

    const expireAt = Date.parse(account.subscriptionExpireTime);
    if (Number.isNaN(expireAt) || expireAt - now.getTime() > deps.horizonMs) {
      skipped.push(account.accountId);
      continue;
    }

    try {
      await deps.events.deleteSubscription(account.subscriptionName);
      const refreshToken = deps.crypto.decrypt(account.encryptedRefreshToken);
      const next = await deps.events.createSubscription({
        accountId: account.accountId,
        refreshToken,
      });
      deps.store.upsertAccount({
        ...account,
        subscriptionName: next.name,
        subscriptionExpireTime: next.expireTime,
      });
      renewed.push(account.accountId);
    } catch (error) {
      failed.push(account.accountId);
      await deps.alertRenewFailure?.({ accountId: account.accountId, error });
    }
  }

  return { renewed, skipped, failed };
}
