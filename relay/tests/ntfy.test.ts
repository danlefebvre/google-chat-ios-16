import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { buildNtfyPayload, publishToNtfy } from "../src/ntfy.js";
import type { NtfyConfig } from "../src/config.js";

describe("buildNtfyPayload", () => {
  it("formats title with account label and space name", () => {
    const payload = buildNtfyPayload({
      accountLabel: "Work",
      spaceTitle: "#eng-standup",
      senderName: "Alice",
      messagePreview: "deploy looks good",
    });

    expect(payload.title).toBe("[Work] #eng-standup");
    expect(payload.message).toBe("Alice: deploy looks good");
  });

  it("truncates long message previews", () => {
    const longText = "a".repeat(300);
    const payload = buildNtfyPayload({
      accountLabel: "Personal",
      spaceTitle: "Family",
      senderName: "Mom",
      messagePreview: longText,
      maxPreviewLength: 200,
    });

    expect(payload.message).toBe(`Mom: ${"a".repeat(200)}`);
    expect(payload.message.length).toBe(205);
  });

  it("includes deep link when space resource name is provided", () => {
    const payload = buildNtfyPayload({
      accountLabel: "Work",
      spaceTitle: "DM · Sam",
      senderName: "Sam",
      messagePreview: "hey",
      spaceResourceName: "spaces/abc123",
      deepLinkScheme: "gchatmulti",
    });

    expect(payload.click).toBe("gchatmulti://space/spaces%2Fabc123");
  });
});

describe("publishToNtfy", () => {
  const config: NtfyConfig = {
    baseUrl: "https://ntfy.sh",
    topic: "secret-topic",
    accessToken: "tok123",
  };

  beforeEach(() => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
      }),
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("POSTs to ntfy topic with preview headers", async () => {
    const payload = buildNtfyPayload({
      accountLabel: "Work",
      spaceTitle: "#eng-standup",
      senderName: "Alice",
      messagePreview: "deploy looks good",
    });

    await publishToNtfy(config, payload);

    expect(fetch).toHaveBeenCalledWith(
      "https://ntfy.sh/secret-topic",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          Title: "[Work] #eng-standup",
          Authorization: "Bearer tok123",
        }),
        body: "Alice: deploy looks good",
      }),
    );
  });

  it("throws when ntfy returns non-ok", async () => {
    vi.mocked(fetch).mockResolvedValueOnce({
      ok: false,
      status: 429,
      text: async () => "rate limited",
    } as Response);

    await expect(
      publishToNtfy(config, {
        title: "t",
        message: "m",
      }),
    ).rejects.toThrow("ntfy publish failed: 429");
  });
});
