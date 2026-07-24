import { describe, expect, it, vi } from "vitest";
import { handlePubSubPush } from "../src/handlers/pubsub.js";
import { AccountStore } from "../src/accounts/store.js";

describe("handlePubSubPush", () => {
  it("publishes ntfy notification for chat message events", async () => {
    const store = new AccountStore();
    store.upsert({
      accountId: "issuer|sub",
      label: "Work",
      refreshToken: "rt",
    });

    const publish = vi.fn().mockResolvedValue(undefined);

    const payload = {
      message: {
        data: Buffer.from(
          JSON.stringify({
            accountId: "issuer|sub",
            event: {
              type: "google.workspace.chat.message.v1.created",
              chatMessage: {
                text: "hello",
                sender: { displayName: "Alice" },
                space: { name: "spaces/AAA", displayName: "#eng" },
              },
            },
          }),
        ).toString("base64"),
      },
    };

    await handlePubSubPush(payload, { store, publish, deepLinkScheme: "gchatmulti" });

    expect(publish).toHaveBeenCalledOnce();
    expect(publish.mock.calls[0][0].title).toBe("[Work] #eng");
    expect(publish.mock.calls[0][0].body).toBe("Alice: hello");
  });

  it("skips muted spaces", async () => {
    const store = new AccountStore();
    store.upsert({
      accountId: "issuer|sub",
      label: "Work",
      refreshToken: "rt",
      mutedSpaces: ["spaces/AAA"],
    });

    const publish = vi.fn();

    const payload = {
      message: {
        data: Buffer.from(
          JSON.stringify({
            accountId: "issuer|sub",
            event: {
              type: "google.workspace.chat.message.v1.created",
              chatMessage: {
                text: "hello",
                sender: { displayName: "Alice" },
                space: { name: "spaces/AAA", displayName: "#eng" },
              },
            },
          }),
        ).toString("base64"),
      },
    };

    await handlePubSubPush(payload, { store, publish, deepLinkScheme: "gchatmulti" });

    expect(publish).not.toHaveBeenCalled();
  });
});
