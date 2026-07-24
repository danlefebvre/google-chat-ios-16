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
    const existing = this.store.getAccount(input.accountId);
    if (existing?.subscriptionName) {
      // Re-register must not orphan the previous Google subscription.
      const refreshForDelete =
        existing.encryptedRefreshToken.length > 0
          ? this.crypto.decrypt(existing.encryptedRefreshToken)
          : input.refreshToken;
      await this.events.deleteSubscription({
        subscriptionName: existing.subscriptionName,
        refreshToken: refreshForDelete,
      });
    }

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
      createdAt: existing?.createdAt ?? new Date().toISOString(),
    };

    this.store.upsertAccount(account);
    return account;
  }

  /**
   * Teardown order (plan): subscription → revoke refresh token →
   * invalidate ntfy binding → wipe store entry.
   * Progress is persisted after each successful external step so retries
   * remain idempotent across partial failures.
   */
  async removeAccount(accountId: string): Promise<void> {
    const existing = this.store.getAccount(accountId);
    if (!existing) {
      return;
    }

    let current = { ...existing };

    if (current.subscriptionName) {
      const refreshToken =
        current.encryptedRefreshToken.length > 0
          ? this.crypto.decrypt(current.encryptedRefreshToken)
          : "";
      if (!refreshToken) {
        throw new Error("missing refresh token for subscription delete");
      }
      await this.events.deleteSubscription({
        subscriptionName: current.subscriptionName,
        refreshToken,
      });
      current = {
        ...current,
        subscriptionName: null,
        subscriptionExpireTime: null,
      };
      this.store.upsertAccount(current);
    }

    if (current.encryptedRefreshToken.length > 0) {
      const refreshToken = this.crypto.decrypt(current.encryptedRefreshToken);
      await this.events.revokeToken(refreshToken);
      current = {
        ...current,
        encryptedRefreshToken: "",
        ntfyBindingActive: false,
      };
      this.store.upsertAccount(current);
    } else if (current.ntfyBindingActive) {
      current = { ...current, ntfyBindingActive: false };
      this.store.upsertAccount(current);
    }

    this.store.deleteAccount(accountId);
  }

  /** True when the presented refresh token matches the stored ciphertext. */
  ownsRefreshToken(accountId: string, refreshToken: string): boolean {
    const existing = this.store.getAccount(accountId);
    if (!existing || !existing.encryptedRefreshToken) {
      return false;
    }
    try {
      return this.crypto.decrypt(existing.encryptedRefreshToken) === refreshToken;
    } catch {
      return false;
    }
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
