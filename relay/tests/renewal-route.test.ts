import request from "supertest";
import { describe, expect, it, vi } from "vitest";
import { createApp } from "../src/app.js";
import { InMemoryStore } from "../src/store.js";

describe("POST /admin/renew-subscriptions", () => {
  it("renews expiring subscriptions", async () => {
    const store = new InMemoryStore();
    store.upsertAccount({
      accountId: "iss|a",
      email: "a@b.com",
      label: "Work",
      encryptedRefreshToken: "v1:x:y:z",
      subscriptionName: "subscriptions/old",
      subscriptionExpireTime: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    });

    const events = {
      createSubscription: vi.fn().mockResolvedValue({
        name: "subscriptions/new",
        expireTime: new Date(Date.now() + 7 * 86400000).toISOString(),
      }),
      deleteSubscription: vi.fn().mockResolvedValue(undefined),
      revokeToken: vi.fn(),
    };

    // Use a crypto that treats the stored token as already-plain for this route test
    // by injecting via register path instead — here we stub decrypt via fake cipher format.
    const app = createApp({
      store,
      ntfy: { baseUrl: "https://ntfy.sh", topic: "t", accessToken: "tk" },
      adminToken: "admin-secret",
      tokenSecret: "unit-test-secret-value",
      eventsClient: events,
    });

    // Replace encrypted token with a real encrypted value
    const { createTokenCrypto } = await import("../src/crypto.js");
    const crypto = createTokenCrypto("unit-test-secret-value");
    const existing = store.getAccount("iss|a")!;
    store.upsertAccount({
      ...existing,
      encryptedRefreshToken: crypto.encrypt("refresh-token"),
    });

    const res = await request(app)
      .post("/admin/renew-subscriptions")
      .set("Authorization", "Bearer admin-secret")
      .send({ horizonHours: 2 });

    expect(res.status).toBe(200);
    expect(res.body.renewed).toEqual(["iss|a"]);
    expect(events.createSubscription).toHaveBeenCalledOnce();
  });
});
