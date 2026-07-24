import { describe, expect, it } from "vitest";
import { parseChatEvent, type ChatMessageEvent } from "../src/events.js";

describe("parseChatEvent", () => {
  it("extracts message details from a Workspace Events payload", () => {
    const event = parseChatEvent({
      type: "google.workspace.chat.message.v1.created",
      data: {
        message: {
          name: "spaces/abc/messages/msg1",
          text: "deploy looks good",
          sender: {
            displayName: "Alice",
          },
          space: {
            name: "spaces/abc",
            displayName: "#eng-standup",
          },
        },
      },
    });

    expect(event).toEqual({
      type: "message.created",
      spaceResourceName: "spaces/abc",
      spaceTitle: "#eng-standup",
      senderName: "Alice",
      messagePreview: "deploy looks good",
    } satisfies ChatMessageEvent);
  });

  it("returns null for unsupported event types", () => {
    expect(
      parseChatEvent({
        type: "google.workspace.chat.membership.v1.created",
        data: {},
      }),
    ).toBeNull();
  });

  it("handles attachment-only messages with a placeholder preview", () => {
    const event = parseChatEvent({
      type: "google.workspace.chat.message.v1.created",
      data: {
        message: {
          name: "spaces/abc/messages/msg2",
          sender: { displayName: "Bob" },
          space: { name: "spaces/abc", displayName: "DM" },
          attachment: [{ name: "file.png" }],
        },
      },
    });

    expect(event?.messagePreview).toBe("[attachment]");
  });
});
