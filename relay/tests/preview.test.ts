import { describe, expect, it } from "vitest";
import { parseChatEvent, shouldNotify } from "../src/events.js";

describe("parseChatEvent", () => {
  it("extracts message created fields from a Workspace Events payload", () => {
    const parsed = parseChatEvent({
      accountId: "iss|sub-work",
      accountLabel: "Work",
      ceType: "google.workspace.chat.message.v1.created",
      data: {
        message: {
          name: "spaces/AAA/messages/BBB",
          space: { name: "spaces/AAA", displayName: "#eng-standup" },
          sender: { displayName: "Alice", name: "users/123" },
          text: "deploy looks good",
          createTime: "2026-07-24T12:00:00Z",
        },
      },
    });

    expect(parsed).toEqual({
      accountId: "iss|sub-work",
      accountLabel: "Work",
      spaceName: "spaces/AAA",
      spaceTitle: "#eng-standup",
      messageName: "spaces/AAA/messages/BBB",
      senderName: "Alice",
      messageText: "deploy looks good",
      createTime: "2026-07-24T12:00:00Z",
      eventType: "message.created",
    });
  });

  it("returns null for unsupported event types", () => {
    const parsed = parseChatEvent({
      accountId: "iss|sub",
      accountLabel: "Work",
      ceType: "google.workspace.chat.membership.v1.created",
      data: {},
    });
    expect(parsed).toBeNull();
  });
});

describe("shouldNotify", () => {
  const baseEvent = {
    accountId: "iss|sub-work",
    accountLabel: "Work",
    spaceName: "spaces/AAA",
    spaceTitle: "#eng-standup",
    messageName: "spaces/AAA/messages/BBB",
    senderName: "Alice",
    messageText: "hi",
    createTime: "2026-07-24T12:00:00Z",
    eventType: "message.created" as const,
  };

  it("skips muted accounts", () => {
    expect(
      shouldNotify(baseEvent, {
        mutedAccountIds: new Set(["iss|sub-work"]),
        mutedSpaceKeys: new Set(),
        quietHours: null,
        now: new Date("2026-07-24T12:00:00Z"),
      }),
    ).toEqual({ notify: false, reason: "account_muted" });
  });

  it("skips muted spaces using composite key", () => {
    expect(
      shouldNotify(baseEvent, {
        mutedAccountIds: new Set(),
        mutedSpaceKeys: new Set(["iss|sub-work:spaces/AAA"]),
        quietHours: null,
        now: new Date("2026-07-24T12:00:00Z"),
      }),
    ).toEqual({ notify: false, reason: "space_muted" });
  });

  it("skips during quiet hours", () => {
    expect(
      shouldNotify(baseEvent, {
        mutedAccountIds: new Set(),
        mutedSpaceKeys: new Set(),
        quietHours: { startHour: 22, endHour: 7, timeZone: "UTC" },
        now: new Date("2026-07-24T23:30:00Z"),
      }),
    ).toEqual({ notify: false, reason: "quiet_hours" });
  });

  it("allows outside quiet hours", () => {
    expect(
      shouldNotify(baseEvent, {
        mutedAccountIds: new Set(),
        mutedSpaceKeys: new Set(),
        quietHours: { startHour: 22, endHour: 7, timeZone: "UTC" },
        now: new Date("2026-07-24T12:00:00Z"),
      }),
    ).toEqual({ notify: true });
  });
});
