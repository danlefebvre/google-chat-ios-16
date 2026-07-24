import request from "supertest";
import { describe, expect, it, vi } from "vitest";
import { createApp } from "../src/app.js";
import { InMemoryStore } from "../src/store.js";

describe("admin API", () => {
  it("rejects missing admin token", async () => {
    const app = createApp({
      store: new InMemoryStore(),
      ntfy: { baseUrl: "https://ntfy.sh", topic: "t", accessToken: "tk" },
      adminToken: "admin-secret",
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
      ntfy: { baseUrl: "https://ntfy.sh", topic: "t", accessToken: "tk" },
      adminToken: "admin-secret",
    });

    const res = await request(app)
      .post("/admin/test-ntfy")
      .set("Authorization", "Bearer admin-secret")
      .send({
        accountLabel: "Work",
        spaceTitle: "#eng-standup",
        senderName: "Alice",
        messageText: "deploy looks good",
      });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledOnce();
    const [, init] = fetchMock.mock.calls[0]!;
    expect(init.headers.Title).toBe("[Work] #eng-standup");
    expect(init.body).toBe("Alice: deploy looks good");

    vi.unstubAllGlobals();
  });

  it("returns 502 when test-ntfy publish fails", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      status: 503,
      text: async () => "busy",
    });
    vi.stubGlobal("fetch", fetchMock);

    const app = createApp({
      store: new InMemoryStore(),
      ntfy: {
        baseUrl: "https://ntfy.sh",
        topic: "t",
        accessToken: "tk",
      },
      adminToken: "admin-secret",
    });

    const res = await request(app)
      .post("/admin/test-ntfy")
      .set("Authorization", "Bearer admin-secret")
      .send({});

    expect(res.status).toBe(502);
    expect(res.body).toEqual({ error: "publish_failed" });
    vi.unstubAllGlobals();
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
      ntfy: { baseUrl: "https://ntfy.sh", topic: "t", accessToken: "tk" },
      adminToken: "admin-secret",
      eventsClient: events,
      tokenSecret: "test-token-secret-32chars!!",
    });

    const register = await request(app).post("/accounts").send({
      accountId: "iss|sub",
      email: "a@b.com",
      label: "Work",
      refreshToken: "rt-user",
    });
    expect(register.status).toBe(201);

    const denied = await request(app)
      .delete("/accounts/iss%7Csub")
      .set("Authorization", "Bearer wrong");
    expect(denied.status).toBe(403);

    const removed = await request(app)
      .delete("/accounts/iss%7Csub")
      .set("Authorization", "Bearer rt-user");
    expect(removed.status).toBe(204);
  });
});
