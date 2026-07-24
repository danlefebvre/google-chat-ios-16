import { describe, it, expect, vi } from "vitest";
import { handlePubSubMessage } from "../src/pubsub-handler.js";
import type { RelayAccount } from "../src/types.js";

function cloudEventPayload(message: Record<string, unknown>) {
  return {
    message: {
      attributes: {
        "ce-type": "google.workspace.chat.message.v1.created",
      },
      data: Buffer.from(JSON.stringify({ message })).toString("base64"),
    },
  };
}

describe("handlePubSubMessage", () => {
  const account: RelayAccount = {
    accountId: "https://accounts.google.com|user1",
    label: "Work",
    refreshToken: "rt",
    subscriptionName: "projects/p/subscriptions/s",
    mutedSpaces: [],
    muted: false,
  };

  it("publishes ntfy notification for chat message event", async () => {
    const publish = vi.fn().mockResolvedValue(undefined);
    const payload = cloudEventPayload({
      name: "spaces/AAA/messages/BBB",
      sender: { displayName: "Alice", name: "users/123" },
      text: "deploy looks good",
      space: { displayName: "#eng-standup", name: "spaces/AAA" },
    });

    await handlePubSubMessage(payload, account, {
      publish,
      muteConfig: { mutedAccounts: [], mutedSpaces: [], quietHours: null },
      now: new Date("2026-07-24T14:00:00Z"),
    });

    expect(publish).toHaveBeenCalledWith({
      title: "[Work] #eng-standup",
      body: "Alice: deploy looks good",
    });
  });

  it("skips publish when account is muted", async () => {
    const publish = vi.fn();
    const payload = cloudEventPayload({
      sender: { displayName: "Alice" },
      text: "hi",
      space: { displayName: "Test", name: "spaces/AAA" },
    });

    await handlePubSubMessage(
      payload,
      { ...account, muted: true },
      {
        publish,
        muteConfig: {
          mutedAccounts: ["https://accounts.google.com|user1"],
          mutedSpaces: [],
          quietHours: null,
        },
        now: new Date("2026-07-24T14:00:00Z"),
      },
    );

    expect(publish).not.toHaveBeenCalled();
  });

  it("skips events without ce-type message.created attribute", async () => {
    const publish = vi.fn();
    const payload = {
      message: {
        attributes: { "ce-type": "google.workspace.chat.message.v1.updated" },
        data: Buffer.from(
          JSON.stringify({
            message: {
              text: "edited",
              space: { name: "spaces/AAA", displayName: "Test" },
              sender: { displayName: "Alice" },
            },
          }),
        ).toString("base64"),
      },
    };

    await handlePubSubMessage(payload, account, {
      publish,
      muteConfig: { mutedAccounts: [], mutedSpaces: [], quietHours: null },
      now: new Date("2026-07-24T14:00:00Z"),
    });

    expect(publish).not.toHaveBeenCalled();
  });
});
