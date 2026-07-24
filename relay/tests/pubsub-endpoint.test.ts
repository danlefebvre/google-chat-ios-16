import { describe, it, expect, vi } from "vitest";
import { createServer } from "../src/server.js";
import type { RelayAccount } from "../src/types.js";

describe("POST /pubsub", () => {
  const account: RelayAccount = {
    accountId: "https://accounts.google.com|user1",
    label: "Work",
    refreshToken: "rt",
    subscriptionName: "projects/p/subscriptions/s",
    mutedSpaces: [],
    muted: false,
  };

  it("accepts Pub/Sub push and publishes to ntfy", async () => {
    const published: Array<{ title: string; body: string }> = [];
    const server = createServer({
      version: "0.1.0-test",
      accounts: {
        list: async () => [account],
      },
      publish: async (n) => {
        published.push(n);
      },
    });

    const payload = {
      message: {
        attributes: {
          "ce-type": "google.workspace.chat.message.v1.created",
        },
        data: Buffer.from(
          JSON.stringify({
            message: {
              sender: { displayName: "Alice" },
              text: "deploy looks good",
              space: { displayName: "#eng-standup", name: "spaces/AAA" },
            },
          }),
        ).toString("base64"),
      },
      subscription: "projects/p/subscriptions/s",
    };

    const res = await server.fetch(
      new Request("http://localhost/pubsub", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      }),
    );

    expect(res.status).toBe(204);
    expect(published).toHaveLength(1);
    expect(published[0].title).toBe("[Work] #eng-standup");
  });
});
