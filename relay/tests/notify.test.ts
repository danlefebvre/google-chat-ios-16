import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import request from "supertest";
import { createApp } from "../src/app.js";
import type { RelayConfig } from "../src/config.js";

const testConfig: RelayConfig = {
  port: 0,
  baseUrl: "https://ntfy.sh",
  topic: "test-topic",
};

describe("POST /test/notify", () => {
  beforeEach(() => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, status: 200 }),
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("publishes a preview notification", async () => {
    const app = createApp(testConfig);
    const response = await request(app)
      .post("/test/notify")
      .send({
        accountLabel: "Work",
        spaceTitle: "#eng-standup",
        senderName: "Alice",
        messagePreview: "deploy looks good",
        spaceResourceName: "spaces/abc",
      });

    expect(response.status).toBe(204);
    expect(fetch).toHaveBeenCalled();
  });

  it("returns 400 when required fields are missing", async () => {
    const app = createApp(testConfig);
    const response = await request(app).post("/test/notify").send({});
    expect(response.status).toBe(400);
  });
});
