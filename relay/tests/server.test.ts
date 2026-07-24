import { describe, it, expect } from "vitest";
import { createServer } from "../src/server.js";

describe("createServer", () => {
  it("responds to GET /health", async () => {
    const server = createServer({ version: "0.1.0-test" });
    const res = await server.fetch(new Request("http://localhost/health"));
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.status).toBe("ok");
    expect(body.version).toBe("0.1.0-test");
  });

  it("responds to POST /test-notify with preview", async () => {
    const published: Array<{ title: string; body: string }> = [];
    const server = createServer({
      version: "0.1.0-test",
      ntfyConfig: { baseUrl: "https://ntfy.sh", topic: "t", accessToken: "tok" },
      publish: async (n) => {
        published.push(n);
      },
    });

    const res = await server.fetch(
      new Request("http://localhost/test-notify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          accountLabel: "Work",
          spaceTitle: "#eng-standup",
          senderName: "Alice",
          messageText: "deploy looks good",
        }),
      }),
    );

    expect(res.status).toBe(200);
    expect(published).toEqual([
      { title: "[Work] #eng-standup", body: "Alice: deploy looks good" },
    ]);
  });
});
