import request from "supertest";
import { describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { InMemoryStore } from "../src/store.js";

describe("GET /health", () => {
  it("returns ok with service metadata", async () => {
    const app = createApp({
      store: new InMemoryStore(),
      ntfy: {
        baseUrl: "https://ntfy.sh",
        topic: "test-topic",
        accessToken: "tk",
      },
      adminToken: "admin-secret",
      tokenSecret: "test-token-secret-32",
    });

    const res = await request(app).get("/health");

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      status: "ok",
      service: "google-chat-ntfy-relay",
    });
    expect(typeof res.body.time).toBe("string");
  });
});
