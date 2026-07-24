import { describe, expect, it, vi } from "vitest";
import request from "supertest";
import { createApp } from "../src/app.js";
import { AccountStore } from "../src/accounts/store.js";

describe("account routes", () => {
  const config = {
    ntfy: { baseUrl: "https://ntfy.sh", topic: "t" },
    port: 8080,
    deepLinkScheme: "gchatmulti",
  };

  it("registers an account for relay notifications", async () => {
    const store = new AccountStore();
    const app = createApp(config, { accountStore: store });

    const res = await request(app)
      .post("/accounts")
      .send({
        accountId: "issuer|sub",
        label: "Work",
        refreshToken: "rt",
      });

    expect(res.status).toBe(201);
    expect(store.get("issuer|sub")?.label).toBe("Work");
  });

  it("tears down an account", async () => {
    const store = new AccountStore();
    store.upsert({
      accountId: "issuer|sub",
      label: "Work",
      refreshToken: "rt",
      subscriptionName: "subscriptions/1",
    });

    const deleteSubscription = vi.fn().mockResolvedValue(undefined);
    const revokeToken = vi.fn().mockResolvedValue(undefined);

    const app = createApp(config, { accountStore: store, deleteSubscription, revokeToken });

    const res = await request(app).delete("/accounts/issuer%7Csub");
    expect(res.status).toBe(204);
    expect(store.get("issuer|sub")).toBeUndefined();
    expect(deleteSubscription).toHaveBeenCalled();
    expect(revokeToken).toHaveBeenCalled();
  });
});
