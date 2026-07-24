import { describe, expect, it, vi, beforeEach } from "vitest";
import { handlePubSubPush } from "../src/pubsub.js";
import type { RelayServices } from "../src/pubsub.js";

describe("handlePubSubPush", () => {
  const account = {
    id: "issuer|sub-work",
    label: "Work",
    refreshToken: "rt",
    subscriptionName: "subscriptions/work",
  };

  let services: RelayServices;

  beforeEach(() => {
    services = {
      getAccountBySubscription: vi.fn().mockReturnValue(account),
      shouldDeliver: vi.fn().mockReturnValue(true),
      publishNotification: vi.fn().mockResolvedValue(undefined),
    };
  });

  it("publishes ntfy notification for chat message events", async () => {
    const envelope = {
      message: {
        data: Buffer.from(
          JSON.stringify({
            type: "google.workspace.chat.message.v1.created",
            data: {
              message: {
                name: "spaces/abc/messages/msg1",
                text: "deploy looks good",
                sender: { displayName: "Alice" },
                space: { name: "spaces/abc", displayName: "#eng-standup" },
              },
            },
          }),
        ).toString("base64"),
        attributes: {
          googclientplussubscription: "subscriptions/work",
        },
      },
    };

    await handlePubSubPush(services, envelope);

    expect(services.publishNotification).toHaveBeenCalledWith({
      accountLabel: "Work",
      spaceTitle: "#eng-standup",
      senderName: "Alice",
      messagePreview: "deploy looks good",
      spaceResourceName: "spaces/abc",
    });
  });

  it("skips publish when account is muted", async () => {
    services.shouldDeliver = vi.fn().mockReturnValue(false);

    const envelope = {
      message: {
        data: Buffer.from(
          JSON.stringify({
            type: "google.workspace.chat.message.v1.created",
            data: {
              message: {
                text: "hi",
                sender: { displayName: "Alice" },
                space: { name: "spaces/abc", displayName: "DM" },
              },
            },
          }),
        ).toString("base64"),
        attributes: {
          googclientplussubscription: "subscriptions/work",
        },
      },
    };

    await handlePubSubPush(services, envelope);

    expect(services.publishNotification).not.toHaveBeenCalled();
  });
});
