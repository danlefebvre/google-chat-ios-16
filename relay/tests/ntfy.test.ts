import { describe, it, expect, vi, beforeEach } from "vitest";
import {
  buildNtfyUrl,
  formatNotification,
  publishToNtfy,
  truncatePreview,
} from "../src/ntfy.js";
import type { NtfyConfig } from "../src/types.js";

const ntfyConfig: NtfyConfig = {
  server: "https://ntfy.sh",
  topic: "secret-topic-abc",
  accessToken: "my-token",
};

describe("truncatePreview", () => {
  it("returns short text unchanged", () => {
    expect(truncatePreview("hello", 100)).toBe("hello");
  });

  it("truncates long text with ellipsis", () => {
    const long = "a".repeat(200);
    const result = truncatePreview(long, 50);
    expect(result.length).toBe(50);
    expect(result.endsWith("…")).toBe(true);
  });
});

describe("formatNotification", () => {
  it("formats title and body with account badge and preview", () => {
    const { title, body } = formatNotification({
      accountLabel: "Work",
      spaceTitle: "#eng-standup",
      sender: "Alice",
      messageText: "deploy looks good",
    });
    expect(title).toBe("[Work] #eng-standup");
    expect(body).toBe("Alice: deploy looks good");
  });

  it("truncates long message previews", () => {
    const { body } = formatNotification({
      accountLabel: "Personal",
      spaceTitle: "Family",
      sender: "Mom",
      messageText: "x".repeat(500),
      maxBodyLength: 80,
    });
    expect(body.length).toBeLessThanOrEqual(80);
    expect(body.startsWith("Mom: ")).toBe(true);
  });
});

describe("buildNtfyUrl", () => {
  it("builds public ntfy.sh URL", () => {
    expect(buildNtfyUrl(ntfyConfig)).toBe(
      "https://ntfy.sh/secret-topic-abc",
    );
  });
});

describe("publishToNtfy", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("POSTs title, body, and auth header", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
    });
    vi.stubGlobal("fetch", fetchMock);

    await publishToNtfy(ntfyConfig, {
      title: "[Work] #eng-standup",
      body: "Alice: deploy looks good",
      tags: ["chat", "work"],
    });

    expect(fetchMock).toHaveBeenCalledOnce();
    const [url, opts] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe("https://ntfy.sh/secret-topic-abc");
    expect(opts.method).toBe("POST");
    expect(opts.body).toBe("Alice: deploy looks good");
    const headers = opts.headers as Record<string, string>;
    expect(headers.Title).toBe("[Work] #eng-standup");
    expect(headers.Tags).toBe("chat,work");
    expect(headers.Authorization).toBe("Bearer my-token");
  });

  it("throws on non-2xx response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: false, status: 429, statusText: "Too Many Requests" }),
    );

    await expect(
      publishToNtfy(ntfyConfig, { title: "t", body: "b" }),
    ).rejects.toThrow(/429/);
  });
});
