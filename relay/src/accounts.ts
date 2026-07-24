import type { AccountStore } from "./store.js";
import type { AccountRecord, EventsClient, TokenCrypto } from "./types.js";

export type RegisterAccountInput = {
  accountId: string;
  email: string;
  label: string;
  refreshToken: string;
};

export class AccountService {
  private readonly store: AccountStore;
  private readonly events: EventsClient;
  private readonly crypto: TokenCrypto;

  constructor(deps: {
    store: AccountStore;
    events: EventsClient;
    crypto: TokenCrypto;
  }) {
    this.store = deps.store;
    this.events = deps.events;
    this.crypto = deps.crypto;
  }

  async registerAccount(input: RegisterAccountInput): Promise<AccountRecord> {
    const subscription = await this.events.createSubscription({
      accountId: input.accountId,
      refreshToken: input.refreshToken,
    });

    const account: AccountRecord = {
      accountId: input.accountId,
      email: input.email,
      label: input.label,
      encryptedRefreshToken: this.crypto.encrypt(input.refreshToken),
      subscriptionName: subscription.name,
      subscriptionExpireTime: subscription.expireTime,
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    };

    this.store.upsertAccount(account);
    return account;
  }

  /**
   * Teardown order (plan): subscription → revoke refresh token →
   * invalidate ntfy binding → wipe store entry.
   */
  async removeAccount(accountId: string): Promise<void> {
    const existing = this.store.getAccount(accountId);
    if (!existing) {
      return;
    }

    if (existing.subscriptionName) {
      await this.events.deleteSubscription(existing.subscriptionName);
    }

    const refreshToken = this.crypto.decrypt(existing.encryptedRefreshToken);
    await this.events.revokeToken(refreshToken);

    this.store.upsertAccount({
      ...existing,
      ntfyBindingActive: false,
      subscriptionName: null,
      subscriptionExpireTime: null,
      encryptedRefreshToken: "",
    });

    this.store.deleteAccount(accountId);
  }

  setAccountMuted(accountId: string, muted: boolean): void {
    const existing = this.store.getAccount(accountId);
    if (!existing) {
      throw new Error(`unknown account: ${accountId}`);
    }
    this.store.upsertAccount({ ...existing, muted });
  }

  setSpaceMuted(
    accountId: string,
    spaceName: string,
    muted: boolean,
  ): void {
    const existing = this.store.getAccount(accountId);
    if (!existing) {
      throw new Error(`unknown account: ${accountId}`);
    }
    const set = new Set(existing.mutedSpaces);
    if (muted) {
      set.add(spaceName);
    } else {
      set.delete(spaceName);
    }
    this.store.upsertAccount({ ...existing, mutedSpaces: [...set] });
  }
}
