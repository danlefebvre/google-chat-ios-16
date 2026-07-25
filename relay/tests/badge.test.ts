import request from "supertest";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createApp } from "../src/app.js";
import { InMemoryStore } from "../src/store.js";

function encodeData(obj: unknown): string {
  return Buffer.from(JSON.stringify(obj), "utf8").toString("base64");
}

describe("POST /badge/reset", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("resets the durable counter so the next Chat push starts at badge 1", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: async () => "ok",
    });
    vi.stubGlobal("fetch", fetchMock);

    const store = new InMemoryStore();
    const events = {
      createSubscription: vi.fn().mockResolvedValue({
        name: "subscriptions/sub-1",
        expireTime: "2026-08-01T00:00:00Z",
      }),
      renewSubscription: vi.fn(),
      deleteSubscription: vi.fn(),
      revokeToken: vi.fn(),
    };

    const app = createApp({
      store,
      bark: {
        baseUrl: "https://api.day.app",
        deviceKey: "test-device-key",
      },
      adminToken: "admin-secret",
      tokenSecret: "test-token-secret-32chars!!",
      eventsClient: events,
      deepLinkScheme: "googlechatmulti",
      verifyAccountOwnership: async () => true,
    });

    const register = await request(app).post("/accounts").send({
      accountId: "iss|sub-work",
      email: "you@work.com",
      label: "Work",
      refreshToken: "rt-user",
    });
    expect(register.status).toBe(201);
    const relayCredential = register.body.relayCredential as string;

    // Simulate a wave of unread notifications (icon would show 9).
    for (let i = 0; i < 9; i += 1) {
      store.incrementBadgeCount();
    }
    expect(store.getBadgeCount()).toBe(9);

    // Opening Bark clears the iOS icon, but without this ack the next push
    // would still send badge: 10.
    const reset = await request(app)
      .post("/badge/reset")
      .set("Authorization", `Bearer ${relayCredential}`);
    expect(reset.status).toBe(200);
    expect(reset.body).toEqual({ ok: true, badge: 0 });
    expect(store.getBadgeCount()).toBe(0);
    // App-side reset must not spam Bark with a "badge cleared" push.
    expect(fetchMock).not.toHaveBeenCalled();

    const res = await request(app)
      .post("/pubsub/push")
      .send({
        message: {
          data: encodeData({
            message: {
              name: "spaces/AAA/messages/BBB",
              space: { name: "spaces/AAA", displayName: "#eng-standup" },
              sender: { displayName: "Alice" },
              text: "deploy looks good",
            },
          }),
          attributes: {
            accountId: "iss|sub-work",
            "ce-type": "google.workspace.chat.message.v1.created",
          },
        },
      });

    expect(res.status).toBe(204);
    expect(fetchMock).toHaveBeenCalledOnce();
    const payload = JSON.parse(fetchMock.mock.calls[0]![1].body as string);
    expect(payload.badge).toBe(1);
  });

  it("rejects missing or unknown relay credentials", async () => {
    const app = createApp({
      store: new InMemoryStore(),
      bark: { baseUrl: "https://api.day.app", deviceKey: "test-device-key" },
      adminToken: "admin-secret",
      tokenSecret: "test-token-secret-32chars!!",
    });

    const missing = await request(app).post("/badge/reset");
    expect(missing.status).toBe(401);

    const wrong = await request(app)
      .post("/badge/reset")
      .set("Authorization", "Bearer not-a-real-credential");
    expect(wrong.status).toBe(403);
  });
});
