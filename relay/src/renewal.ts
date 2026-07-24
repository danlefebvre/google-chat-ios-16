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
      const refreshToken = deps.crypto.decrypt(account.encryptedRefreshToken);
      // Patch in place — Workspace Events allows only one active subscription
      // per resource; delete/recreate can leave the account unsubscribed.
      const next = await deps.events.renewSubscription({
        subscriptionName: account.subscriptionName,
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
