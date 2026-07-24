import { describe, expect, it } from "vitest";
import { formatNtfyNotification } from "../src/ntfy/format.js";

describe("formatNtfyNotification", () => {
  it("formats title with account badge and space name", () => {
    const result = formatNtfyNotification({
      accountLabel: "Work",
      spaceTitle: "#eng-standup",
      senderName: "Alice",
      messageText: "deploy looks good",
    });

    expect(result.title).toBe("[Work] #eng-standup");
    expect(result.body).toBe("Alice: deploy looks good");
  });

  it("truncates long message previews", () => {
    const long = "a".repeat(300);
    const result = formatNtfyNotification({
      accountLabel: "Personal",
      spaceTitle: "Family",
      senderName: "Mom",
      messageText: long,
      maxBodyLength: 120,
    });

    expect(result.body.length).toBeLessThanOrEqual(120 + "Mom: ".length);
    expect(result.body).toMatch(/…$/);
  });

  it("includes deep link when space resource name is provided", () => {
    const result = formatNtfyNotification({
      accountLabel: "Work",
      spaceTitle: "DM · Sam",
      senderName: "Sam",
      messageText: "hey",
      spaceResourceName: "spaces/AAA",
      deepLinkScheme: "gchatmulti",
    });

    expect(result.click).toBe("gchatmulti://space/spaces%2FAAA");
  });
});
