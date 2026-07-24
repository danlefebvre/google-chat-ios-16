import { describe, expect, it, vi } from "vitest";
import { AccountService } from "../src/accounts.js";
import { InMemoryStore } from "../src/store.js";

describe("AccountService", () => {
  it("registers an account with encrypted refresh token and ntfy binding", async () => {
    const store = new InMemoryStore();
    const events = {
      createSubscription: vi.fn().mockResolvedValue({
        name: "subscriptions/sub-1",
        expireTime: "2026-08-01T00:00:00Z",
      }),
      deleteSubscription: vi.fn().mockResolvedValue(undefined),
      revokeToken: vi.fn().mockResolvedValue(undefined),
    };
    const crypto = {
      encrypt: (plain: string) => `enc:${plain}`,
      decrypt: (cipher: string) => cipher.replace(/^enc:/, ""),
    };

    const service = new AccountService({ store, events, crypto });

    const account = await service.registerAccount({
      accountId: "https://accounts.google.com|sub-work",
      email: "you@work.com",
      label: "Work",
      refreshToken: "refresh-plain",
    });

    expect(account.accountId).toBe("https://accounts.google.com|sub-work");
    expect(account.subscriptionName).toBe("subscriptions/sub-1");
    expect(store.getAccount(account.accountId)?.encryptedRefreshToken).toBe(
      "enc:refresh-plain",
    );
    expect(events.createSubscription).toHaveBeenCalledOnce();
  });

  it("tears down in order: subscription → revoke token → invalidate ntfy binding → wipe store", async () => {
    const store = new InMemoryStore();
    const order: string[] = [];
    const events = {
      createSubscription: vi.fn(),
      deleteSubscription: vi.fn().mockImplementation(async () => {
        order.push("delete_subscription");
      }),
      revokeToken: vi.fn().mockImplementation(async () => {
        order.push("revoke_token");
      }),
    };
    const crypto = {
      encrypt: (p: string) => p,
      decrypt: (c: string) => c,
    };

    store.upsertAccount({
      accountId: "iss|sub",
      email: "a@b.com",
      label: "Work",
      encryptedRefreshToken: "rt",
      subscriptionName: "subscriptions/sub-1",
      subscriptionExpireTime: "2026-08-01T00:00:00Z",
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    });

    const service = new AccountService({ store, events, crypto });
    await service.removeAccount("iss|sub");

    expect(order).toEqual(["delete_subscription", "revoke_token"]);
    expect(store.getAccount("iss|sub")).toBeUndefined();
  });
});
