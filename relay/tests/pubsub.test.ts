import request from "supertest";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createApp } from "../src/app.js";
import { InMemoryStore } from "../src/store.js";

function encodeData(obj: unknown): string {
  return Buffer.from(JSON.stringify(obj), "utf8").toString("base64");
}

describe("POST /pubsub/push", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("publishes a preview notification for a message.created event", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: async () => "ok",
    });
    vi.stubGlobal("fetch", fetchMock);

    const store = new InMemoryStore();
    store.upsertAccount({
      accountId: "iss|sub-work",
      email: "you@work.com",
      label: "Work",
      encryptedRefreshToken: "enc",
      subscriptionName: "subscriptions/sub-1",
      subscriptionExpireTime: "2026-08-01T00:00:00Z",
      ntfyBindingActive: true,
      muted: false,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    });

    const app = createApp({
      store,
      ntfy: {
        baseUrl: "https://ntfy.sh",
        topic: "secret-topic",
        accessToken: "tk",
      },
      adminToken: "admin-secret",
      deepLinkScheme: "googlechatmulti",
    });

    const messagePayload = {
      message: {
        name: "spaces/AAA/messages/BBB",
        space: { name: "spaces/AAA", displayName: "#eng-standup" },
        sender: { displayName: "Alice" },
        text: "deploy looks good",
        createTime: "2026-07-24T12:00:00Z",
      },
    };

    const res = await request(app)
      .post("/pubsub/push")
      .send({
        message: {
          data: encodeData(messagePayload),
          attributes: {
            accountId: "iss|sub-work",
            "ce-type": "google.workspace.chat.message.v1.created",
          },
        },
      });

    expect(res.status).toBe(204);
    expect(fetchMock).toHaveBeenCalledOnce();
    const [, init] = fetchMock.mock.calls[0]!;
    expect(init.headers.Title).toBe("[Work] #eng-standup");
    expect(init.body).toBe("Alice: deploy looks good");
  });

  it("acks muted events without publishing", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const store = new InMemoryStore();
    store.upsertAccount({
      accountId: "iss|sub-work",
      email: "you@work.com",
      label: "Work",
      encryptedRefreshToken: "enc",
      subscriptionName: "subscriptions/sub-1",
      subscriptionExpireTime: "2026-08-01T00:00:00Z",
      ntfyBindingActive: true,
      muted: true,
      mutedSpaces: [],
      createdAt: new Date().toISOString(),
    });

    const app = createApp({
      store,
      ntfy: {
        baseUrl: "https://ntfy.sh",
        topic: "secret-topic",
        accessToken: "tk",
      },
      adminToken: "admin-secret",
    });

    const res = await request(app)
      .post("/pubsub/push")
      .send({
        message: {
          data: encodeData({
            message: {
              name: "spaces/AAA/messages/BBB",
              space: { name: "spaces/AAA", displayName: "S" },
              sender: { displayName: "A" },
              text: "hi",
            },
          }),
          attributes: {
            accountId: "iss|sub-work",
            "ce-type": "google.workspace.chat.message.v1.created",
          },
        },
      });

    expect(res.status).toBe(204);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
