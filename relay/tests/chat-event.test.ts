import { describe, expect, it } from "vitest";
import { parseChatEvent } from "../src/handlers/chat-event.js";

describe("parseChatEvent", () => {
  it("extracts message details from Workspace Events payload", () => {
    const event = parseChatEvent({
      type: "google.workspace.chat.message.v1.created",
      chatMessage: {
        name: "spaces/AAA/messages/BBB",
        text: "deploy looks good",
        sender: { displayName: "Alice", name: "users/123" },
        space: { name: "spaces/AAA", displayName: "#eng-standup" },
      },
    });

    expect(event).toEqual({
      type: "message.created",
      spaceResourceName: "spaces/AAA",
      spaceTitle: "#eng-standup",
      senderName: "Alice",
      messageText: "deploy looks good",
    });
  });

  it("returns null for unsupported event types", () => {
    expect(parseChatEvent({ type: "other" })).toBeNull();
  });
});
