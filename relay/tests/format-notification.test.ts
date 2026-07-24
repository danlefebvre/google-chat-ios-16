import { describe, it, expect } from "vitest";
import { formatNotification } from "../src/format-notification.js";

describe("formatNotification", () => {
  it("formats title with account label and space name", () => {
    const result = formatNotification({
      accountLabel: "Work",
      spaceTitle: "#eng-standup",
      senderName: "Alice",
      messageText: "deploy looks good",
    });

    expect(result.title).toBe("[Work] #eng-standup");
    expect(result.body).toBe("Alice: deploy looks good");
  });

  it("truncates long message bodies to 200 characters", () => {
    const longText = "a".repeat(300);
    const result = formatNotification({
      accountLabel: "Personal",
      spaceTitle: "Family",
      senderName: "Mom",
      messageText: longText,
    });

    expect(result.body).toBe(`Mom: ${"a".repeat(194)}…`);
    expect(result.body.length).toBe(200);
  });

  it("handles empty message text", () => {
    const result = formatNotification({
      accountLabel: "Work",
      spaceTitle: "DM · Sam",
      senderName: "Sam",
      messageText: "",
    });

    expect(result.body).toBe("Sam:");
  });
});
