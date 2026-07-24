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
});
