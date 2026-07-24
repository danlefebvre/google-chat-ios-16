import { describe, expect, it, vi } from "vitest";
import { renewExpiringSubscriptions } from "../src/renewal.js";
import { InMemoryStore } from "../src/store.js";

describe("renewExpiringSubscriptions", () => {
  it("renews subscriptions expiring within the horizon via patch", async () => {
    const store = new InMemoryStore();
    store.upsertAccount({
      accountId: "iss|a",
      email: "a@b.com",
      label: "Work",
      encryptedRefreshToken: "enc:rt",
      subscriptionName: "subscriptions/old",
      subscriptionExpireTime: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    });
    store.upsertAccount({
      accountId: "iss|b",
      email: "b@b.com",
      label: "Personal",
      encryptedRefreshToken: "enc:rt2",
      subscriptionName: "subscriptions/ok",
      subscriptionExpireTime: new Date(
        Date.now() + 10 * 24 * 60 * 60 * 1000,
      ).toISOString(),
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    });

    const events = {
      createSubscription: vi.fn(),
      renewSubscription: vi.fn().mockResolvedValue({
        name: "subscriptions/old",
        expireTime: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(),
      }),
      deleteSubscription: vi.fn(),
      revokeToken: vi.fn(),
    };
    const crypto = {
      encrypt: (p: string) => `enc:${p}`,
      decrypt: (c: string) => c.replace(/^enc:/, ""),
    };
    const alert = vi.fn();

    const result = await renewExpiringSubscriptions({
      store,
      events,
      crypto,
      horizonMs: 2 * 60 * 60 * 1000,
      alertRenewFailure: alert,
    });

    expect(result.renewed).toEqual(["iss|a"]);
    expect(result.skipped).toEqual(["iss|b"]);
    expect(events.deleteSubscription).not.toHaveBeenCalled();
    expect(events.renewSubscription).toHaveBeenCalledWith({
      subscriptionName: "subscriptions/old",
      refreshToken: "rt",
    });
    expect(store.getAccount("iss|a")?.subscriptionName).toBe("subscriptions/old");
    expect(alert).not.toHaveBeenCalled();
  });

  it("alerts via callback when renew fails", async () => {
    const store = new InMemoryStore();
    store.upsertAccount({
      accountId: "iss|a",
      email: "a@b.com",
      label: "Work",
      encryptedRefreshToken: "enc:rt",
      subscriptionName: "subscriptions/old",
      subscriptionExpireTime: new Date(Date.now() + 1000).toISOString(),
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    });

    const events = {
      createSubscription: vi.fn(),
      renewSubscription: vi.fn().mockRejectedValue(new Error("boom")),
      deleteSubscription: vi.fn(),
      revokeToken: vi.fn(),
    };
    const alert = vi.fn();

    const result = await renewExpiringSubscriptions({
      store,
      events,
      crypto: {
        encrypt: (p) => p,
        decrypt: (c) => c.replace(/^enc:/, ""),
      },
      horizonMs: 60 * 60 * 1000,
      alertRenewFailure: alert,
    });

    expect(result.failed).toEqual(["iss|a"]);
    expect(alert).toHaveBeenCalledWith(
      expect.objectContaining({ accountId: "iss|a" }),
    );
  });
});
