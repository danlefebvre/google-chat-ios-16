import { describe, it, expect, vi, beforeEach } from "vitest";
import { createApp } from "../src/index.js";
import type { AppConfig, RelayDeps } from "../src/types.js";
import { InMemoryAccountStore } from "../src/store.js";

function testConfig(): AppConfig {
  return {
    version: "0.1.0-test",
    ntfy: {
      server: "https://ntfy.sh",
      topic: "test-topic",
      accessToken: "tok",
    },
    google: { projectId: "test-project" },
    pubsub: { subscription: "sub" },
    port: 0,
    quietHours: null,
  };
}

describe("HTTP server", () => {
  let publish: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    publish = vi.fn().mockResolvedValue(undefined);
  });

  function appWithDeps() {
    const config = testConfig();
    const store = new InMemoryAccountStore();
    const deps: RelayDeps = {
      publish,
      mutes: { accounts: new Set(), spaces: new Set() },
      quietHours: null,
      accounts: new Map(),
    };
    return { app: createApp({ config, store, deps }), store, deps, config };
  }

  it("GET /health returns ok", async () => {
    const { app, config } = appWithDeps();
    const server = app.listen(0);
    const port = (server.address() as { port: number }).port;
    const res = await fetch(`http://127.0.0.1:${port}/health`);
    const body = await res.json();
    expect(body.status).toBe("ok");
    expect(body.version).toBe(config.version);
    server.close();
  });

  it("POST /test/notify publishes to ntfy", async () => {
    const { app } = appWithDeps();
    const server = app.listen(0);
    const port = (server.address() as { port: number }).port;
    const res = await fetch(`http://127.0.0.1:${port}/test/notify`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: "[Work] test",
        body: "Alice: hello",
      }),
    });
    expect(res.status).toBe(200);
    expect(publish).toHaveBeenCalledOnce();
    server.close();
  });

  it("POST /pubsub/push routes chat events", async () => {
    const { app, store } = appWithDeps();
    store.set({
      accountId: "acct-1",
      label: "Work",
      refreshToken: "rt",
      subscriptionName: "projects/p/subscriptions/s",
    });
    const envelope = {
      payload: {
        message: {
          text: "hi there",
          sender: { displayName: "Alice" },
          space: { name: "spaces/X", displayName: "Standup" },
        },
      },
    };
    const data = Buffer.from(JSON.stringify(envelope)).toString("base64");

    const server = app.listen(0);
    const port = (server.address() as { port: number }).port;
    const res = await fetch(`http://127.0.0.1:${port}/pubsub/push`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Account-Id": "acct-1",
      },
      body: JSON.stringify({ message: { data } }),
    });
    const body = await res.json();
    expect(body.published).toBe(true);
    expect(publish).toHaveBeenCalledOnce();
    server.close();
  });
});
