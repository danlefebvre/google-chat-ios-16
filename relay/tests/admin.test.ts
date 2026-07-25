import request from "supertest";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createApp } from "../src/app.js";
import { InMemoryStore } from "../src/store.js";

describe("admin API", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("rejects missing admin token", async () => {
    const app = createApp({
      store: new InMemoryStore(),
      bark: { baseUrl: "https://api.day.app", deviceKey: "test-device-key" },
      adminToken: "admin-secret",
      tokenSecret: "test-token-secret-32",
      eventsClient: {
        createSubscription: vi.fn(),
        renewSubscription: vi.fn(),
        deleteSubscription: vi.fn(),
        revokeToken: vi.fn(),
      },
    });

    const res = await request(app).post("/admin/accounts").send({});
    expect(res.status).toBe(401);
  });

  it("publishes a manual test notification", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: async () => "ok",
    });
    vi.stubGlobal("fetch", fetchMock);

    const app = createApp({
      store: new InMemoryStore(),
      bark: { baseUrl: "https://api.day.app", deviceKey: "test-device-key" },
      adminToken: "admin-secret",
      tokenSecret: "test-token-secret-32",
    });

    const res = await request(app)
      .post("/admin/test-bark")
      .set("Authorization", "Bearer admin-secret")
      .send({
        accountLabel: "Work",
        spaceTitle: "#eng-standup",
        senderName: "Alice",
        messageText: "deploy looks good",
      });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true, badge: 1 });
    expect(fetchMock).toHaveBeenCalledOnce();
    const [url, init] = fetchMock.mock.calls[0]!;
    expect(url).toBe("https://api.day.app/test-device-key");
    expect(init.headers["Content-Type"]).toContain("application/json");
    const payload = JSON.parse(init.body as string);
    expect(payload.title).toBe("[Work] #eng-standup");
    expect(payload.body).toBe("Alice: deploy looks good");
    expect(payload.badge).toBe(1);
    expect(payload.sound).toBe("birdsong");
  });

  it("returns 502 when test-bark publish fails", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      status: 503,
      text: async () => "busy",
    });
    vi.stubGlobal("fetch", fetchMock);

    const app = createApp({
      store: new InMemoryStore(),
      bark: {
        baseUrl: "https://api.day.app",
        deviceKey: "test-device-key",
      },
      adminToken: "admin-secret",
      tokenSecret: "test-token-secret-32",
    });

    const res = await request(app)
      .post("/admin/test-bark")
      .set("Authorization", "Bearer admin-secret")
      .send({});

    expect(res.status).toBe(502);
    expect(res.body).toEqual({ error: "publish_failed" });
  });

  it("registers and removes accounts via user-scoped routes without admin token", async () => {
    const events = {
      createSubscription: vi.fn().mockResolvedValue({
        name: "subscriptions/u1",
        expireTime: "2026-08-01T00:00:00Z",
      }),
      renewSubscription: vi.fn(),
      deleteSubscription: vi.fn().mockResolvedValue(undefined),
      revokeToken: vi.fn().mockResolvedValue(undefined),
    };
    const app = createApp({
      store: new InMemoryStore(),
      bark: { baseUrl: "https://api.day.app", deviceKey: "test-device-key" },
      adminToken: "admin-secret",
      eventsClient: events,
      tokenSecret: "test-token-secret-32chars!!",
      verifyAccountOwnership: async ({ accountId, email, refreshToken }) =>
        accountId === "iss|sub" &&
        email === "a@b.com" &&
        refreshToken === "rt-user",
    });

    const register = await request(app).post("/accounts").send({
      accountId: "iss|sub",
      email: "a@b.com",
      label: "Work",
      refreshToken: "rt-user",
    });
    expect(register.status).toBe(201);
    expect(typeof register.body.relayCredential).toBe("string");
    expect(register.body.relayCredential.length).toBeGreaterThan(16);
    const relayCredential = register.body.relayCredential as string;

    const mismatched = await request(app).post("/accounts").send({
      accountId: "iss|other",
      email: "a@b.com",
      label: "Work",
      refreshToken: "rt-user",
    });
    expect(mismatched.status).toBe(403);

    const denied = await request(app)
      .delete("/accounts")
      .query({ accountId: "iss|sub" })
      .set("Authorization", "Bearer wrong");
    expect(denied.status).toBe(403);

    // Refresh token must not authorize teardown — only the relay credential.
    const refreshDenied = await request(app)
      .delete("/accounts")
      .query({ accountId: "iss|sub" })
      .set("Authorization", "Bearer rt-user");
    expect(refreshDenied.status).toBe(403);

    const removed = await request(app)
      .delete("/accounts")
      .query({ accountId: "iss|sub" })
      .set("Authorization", `Bearer ${relayCredential}`);
    expect(removed.status).toBe(204);
  });

  it("removes accounts whose id contains https:// via query param", async () => {
    const accountId = "https://accounts.google.com|117792051509045443077";
    const events = {
      createSubscription: vi.fn().mockResolvedValue({
        name: "subscriptions/u1",
        expireTime: "2026-08-01T00:00:00Z",
      }),
      renewSubscription: vi.fn(),
      deleteSubscription: vi.fn().mockResolvedValue(undefined),
      revokeToken: vi.fn().mockResolvedValue(undefined),
    };
    const app = createApp({
      store: new InMemoryStore(),
      bark: { baseUrl: "https://api.day.app", deviceKey: "test-device-key" },
      adminToken: "admin-secret",
      eventsClient: events,
      tokenSecret: "test-token-secret-32chars!!",
      verifyAccountOwnership: async () => true,
    });

    const register = await request(app).post("/accounts").send({
      accountId,
      email: "a@b.com",
      label: "Personal",
      refreshToken: "rt-user",
    });
    expect(register.status).toBe(201);
    const relayCredential = register.body.relayCredential as string;

    const removed = await request(app)
      .delete("/accounts")
      .query({ accountId })
      .set("Authorization", `Bearer ${relayCredential}`);
    expect(removed.status).toBe(204);
  });

  it("updates account label via PATCH with relay credential", async () => {
    const store = new InMemoryStore();
    const events = {
      createSubscription: vi.fn().mockResolvedValue({
        name: "subscriptions/u1",
        expireTime: "2026-08-01T00:00:00Z",
      }),
      renewSubscription: vi.fn(),
      deleteSubscription: vi.fn().mockResolvedValue(undefined),
      revokeToken: vi.fn().mockResolvedValue(undefined),
    };
    const app = createApp({
      store,
      bark: { baseUrl: "https://api.day.app", deviceKey: "test-device-key" },
      adminToken: "admin-secret",
      eventsClient: events,
      tokenSecret: "test-token-secret-32chars!!",
      verifyAccountOwnership: async () => true,
    });

    const accountId = "https://accounts.google.com|label-edit";
    const register = await request(app).post("/accounts").send({
      accountId,
      email: "a@b.com",
      label: "Work",
      refreshToken: "rt-user",
    });
    expect(register.status).toBe(201);
    const relayCredential = register.body.relayCredential as string;

    const denied = await request(app)
      .patch("/accounts")
      .query({ accountId })
      .set("Authorization", "Bearer wrong")
      .send({ label: "Consulting" });
    expect(denied.status).toBe(403);

    const missing = await request(app)
      .patch("/accounts")
      .query({ accountId })
      .set("Authorization", `Bearer ${relayCredential}`)
      .send({});
    expect(missing.status).toBe(400);

    const updated = await request(app)
      .patch("/accounts")
      .query({ accountId })
      .set("Authorization", `Bearer ${relayCredential}`)
      .send({ label: "  Consulting  " });
    expect(updated.status).toBe(200);
    expect(updated.body).toEqual({ ok: true, label: "Consulting" });
    expect(store.getAccount(accountId)?.label).toBe("Consulting");
    // Label edit must not recreate the Workspace Events subscription.
    expect(events.createSubscription).toHaveBeenCalledTimes(1);
    expect(events.deleteSubscription).not.toHaveBeenCalled();
  });
});
