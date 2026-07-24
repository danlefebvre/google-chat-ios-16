import { afterEach, describe, expect, it, vi } from "vitest";
import { NtfyPublisher, formatNtfyNotification } from "../src/ntfy.js";

describe("formatNtfyNotification", () => {
  it("formats title as [Account] space and body as sender + truncated text", () => {
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
    const long = "x".repeat(300);
    const result = formatNtfyNotification({
      accountLabel: "Personal",
      spaceTitle: "Family",
      senderName: "Mom",
      messageText: long,
      maxBodyLength: 80,
    });

    expect(result.body.length).toBeLessThanOrEqual(80);
    expect(result.body.startsWith("Mom: ")).toBe(true);
    expect(result.body.endsWith("…")).toBe(true);
  });

  it("falls back when message text is empty", () => {
    const result = formatNtfyNotification({
      accountLabel: "Work",
      spaceTitle: "DM · Sam",
      senderName: "Sam",
      messageText: "",
    });

    expect(result.body).toBe("Sam: (attachment or empty message)");
  });
});

describe("NtfyPublisher", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("POSTs to ntfy.sh topic with title, body, and auth token", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: async () => "ok",
    });
    vi.stubGlobal("fetch", fetchMock);

    const publisher = new NtfyPublisher({
      baseUrl: "https://ntfy.sh",
      topic: "secret-topic-abc",
      accessToken: "tk_test",
    });

    await publisher.publish({
      title: "[Work] #eng-standup",
      body: "Alice: deploy looks good",
      tags: ["speech_balloon"],
      clickUrl: "googlechatmulti://space/spaces/AAA",
    });

    expect(fetchMock).toHaveBeenCalledOnce();
    const [url, init] = fetchMock.mock.calls[0]!;
    expect(url).toBe("https://ntfy.sh/secret-topic-abc");
    expect(init.method).toBe("POST");
    expect(init.headers["Authorization"]).toBe("Bearer tk_test");
    expect(init.headers["Title"]).toBe("[Work] #eng-standup");
    expect(init.headers["Tags"]).toBe("speech_balloon");
    expect(init.headers["Click"]).toBe("googlechatmulti://space/spaces/AAA");
    expect(init.body).toBe("Alice: deploy looks good");
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });

  it("retries failed deliveries then throws", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce({ ok: false, status: 503, text: async () => "busy" })
      .mockResolvedValueOnce({ ok: false, status: 503, text: async () => "busy" })
      .mockResolvedValueOnce({ ok: false, status: 503, text: async () => "busy" });
    vi.stubGlobal("fetch", fetchMock);

    const publisher = new NtfyPublisher({
      baseUrl: "https://ntfy.sh",
      topic: "t",
      accessToken: "tk",
      maxRetries: 2,
      retryDelayMs: 0,
    });

    await expect(
      publisher.publish({ title: "t", body: "b" }),
    ).rejects.toThrow(/ntfy publish failed/i);

    expect(fetchMock).toHaveBeenCalledTimes(3);
  });
});
