import { describe, expect, it } from "vitest";
import request from "supertest";
import { createApp } from "../src/app.js";
import type { RelayConfig } from "../src/config.js";

const testConfig: RelayConfig = {
  port: 0,
  baseUrl: "https://ntfy.sh",
  topic: "test-topic",
  accessToken: undefined,
};

describe("health endpoint", () => {
  it("returns 200 with ok status", async () => {
    const app = createApp(testConfig);
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: "ok" });
  });
});
