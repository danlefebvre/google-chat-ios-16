import { describe, expect, it, vi } from "vitest";
import { AccountService } from "../src/accounts.js";
import { InMemoryStore } from "../src/store.js";

function cryptoStub() {
  return {
    encrypt: (plain: string) => `enc:${plain}`,
    decrypt: (cipher: string) => cipher.replace(/^enc:/, ""),
  };
}

describe("AccountService", () => {
  it("registers an account with encrypted refresh token and ntfy binding", async () => {
    const store = new InMemoryStore();
    const events = {
      createSubscription: vi.fn().mockResolvedValue({
        name: "subscriptions/sub-1",
        expireTime: "2026-08-01T00:00:00Z",
      }),
      renewSubscription: vi.fn(),
      deleteSubscription: vi.fn().mockResolvedValue(undefined),
      revokeToken: vi.fn().mockResolvedValue(undefined),
    };

    const service = new AccountService({ store, events, crypto: cryptoStub() });

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
    expect(events.deleteSubscription).not.toHaveBeenCalled();
  });

  it("deletes the previous subscription when re-registering the same account", async () => {
    const store = new InMemoryStore();
    store.upsertAccount({
      accountId: "iss|sub",
      email: "a@b.com",
      label: "Work",
      encryptedRefreshToken: "enc:old-rt",
      subscriptionName: "subscriptions/old",
      subscriptionExpireTime: "2026-08-01T00:00:00Z",
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: "2026-01-01T00:00:00Z",
    });

    const events = {
      createSubscription: vi.fn().mockResolvedValue({
        name: "subscriptions/new",
        expireTime: "2026-08-02T00:00:00Z",
      }),
      renewSubscription: vi.fn(),
      deleteSubscription: vi.fn().mockResolvedValue(undefined),
      revokeToken: vi.fn(),
    };

    const service = new AccountService({ store, events, crypto: cryptoStub() });
    await service.registerAccount({
      accountId: "iss|sub",
      email: "a@b.com",
      label: "Work",
      refreshToken: "new-rt",
    });

    expect(events.deleteSubscription).toHaveBeenCalledWith({
      subscriptionName: "subscriptions/old",
      refreshToken: "old-rt",
    });
    expect(store.getAccount("iss|sub")?.subscriptionName).toBe(
      "subscriptions/new",
    );
  });

  it("tears down in order: subscription → revoke token → wipe store", async () => {
    const store = new InMemoryStore();
    const order: string[] = [];
    const events = {
      createSubscription: vi.fn(),
      renewSubscription: vi.fn(),
      deleteSubscription: vi.fn().mockImplementation(async () => {
        order.push("delete_subscription");
      }),
      revokeToken: vi.fn().mockImplementation(async () => {
        order.push("revoke_token");
      }),
    };

    store.upsertAccount({
      accountId: "iss|sub",
      email: "a@b.com",
      label: "Work",
      encryptedRefreshToken: "enc:rt",
      subscriptionName: "subscriptions/sub-1",
      subscriptionExpireTime: "2026-08-01T00:00:00Z",
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    });

    const service = new AccountService({ store, events, crypto: cryptoStub() });
    await service.removeAccount("iss|sub");

    expect(order).toEqual(["delete_subscription", "revoke_token"]);
    expect(events.deleteSubscription).toHaveBeenCalledWith({
      subscriptionName: "subscriptions/sub-1",
      refreshToken: "rt",
    });
    expect(store.getAccount("iss|sub")).toBeUndefined();
  });

  it("retries teardown after partial failure without re-deleting subscription", async () => {
    const store = new InMemoryStore();
    const events = {
      createSubscription: vi.fn(),
      renewSubscription: vi.fn(),
      deleteSubscription: vi.fn().mockResolvedValue(undefined),
      revokeToken: vi
        .fn()
        .mockRejectedValueOnce(new Error("revoke flaky"))
        .mockResolvedValueOnce(undefined),
    };

    store.upsertAccount({
      accountId: "iss|sub",
      email: "a@b.com",
      label: "Work",
      encryptedRefreshToken: "enc:rt",
      subscriptionName: "subscriptions/sub-1",
      subscriptionExpireTime: "2026-08-01T00:00:00Z",
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    });

    const service = new AccountService({ store, events, crypto: cryptoStub() });
    await expect(service.removeAccount("iss|sub")).rejects.toThrow(/revoke flaky/);

    // First step persisted: subscription cleared, token still present.
    expect(store.getAccount("iss|sub")?.subscriptionName).toBeNull();
    expect(store.getAccount("iss|sub")?.encryptedRefreshToken).toBe("enc:rt");

    await service.removeAccount("iss|sub");
    expect(events.deleteSubscription).toHaveBeenCalledTimes(1);
    expect(events.revokeToken).toHaveBeenCalledTimes(2);
    expect(store.getAccount("iss|sub")).toBeUndefined();
  });
});
