import { describe, it, expect } from "vitest";
import {
  parsePubSubPush,
  extractChatMessageEvent,
} from "../src/pubsub.js";

describe("parsePubSubPush", () => {
  it("decodes base64 Pub/Sub data", () => {
    const payload = { type: "MESSAGE", space: "spaces/AAA" };
    const data = Buffer.from(JSON.stringify(payload)).toString("base64");
    const body = {
      message: {
        data,
        messageId: "msg-1",
        publishTime: "2026-01-01T00:00:00Z",
      },
      subscription: "projects/p/subscriptions/s",
    };
    const parsed = parsePubSubPush(body);
    expect(parsed).toEqual(payload);
  });

  it("throws on missing message data", () => {
    expect(() => parsePubSubPush({ message: {} })).toThrow(/data/);
  });
});

describe("extractChatMessageEvent", () => {
  it("extracts message fields from Workspace Event envelope", () => {
    const event = extractChatMessageEvent({
      "@type": "type.googleapis.com/google.apps.events.subscriptions.v1.SubscriptionEvent",
      payload: {
        message: {
          name: "spaces/AAA/messages/BBB",
          text: "deploy looks good",
          sender: { name: "users/123", displayName: "Alice" },
          space: { name: "spaces/AAA", displayName: "#eng-standup" },
          createTime: "2026-07-24T12:00:00Z",
        },
      },
    });
    expect(event).toEqual({
      spaceName: "spaces/AAA",
      spaceTitle: "#eng-standup",
      senderName: "Alice",
      messageText: "deploy looks good",
      messageName: "spaces/AAA/messages/BBB",
      createTime: "2026-07-24T12:00:00Z",
    });
  });

  it("returns null for non-message events", () => {
    expect(extractChatMessageEvent({ payload: { space: {} } })).toBeNull();
  });
});
