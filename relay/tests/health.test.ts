import { describe, expect, it, afterAll } from "vitest";
import type { AddressInfo } from "node:net";
import { createApp } from "../src/app.js";

describe("health endpoint", () => {
  const config = {
    ntfy: { baseUrl: "https://ntfy.sh", topic: "t" },
    port: 8080,
    deepLinkScheme: "gchatmulti",
  };

  const app = createApp(config);
  const server = app.listen(0);
  const port = (server.address() as AddressInfo).port;

  afterAll(() => {
    server.close();
  });

  it("returns ok status", async () => {
    const res = await fetch(`http://127.0.0.1:${port}/health`);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: "ok" });
  });
});
