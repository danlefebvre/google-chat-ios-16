import { afterEach, describe, expect, it, vi } from "vitest";
import {
  BarkPublisher,
  formatPushNotification,
} from "../src/bark.js";

describe("formatPushNotification", () => {
  it("formats title as [Account] space and body as sender + truncated text", () => {
    const result = formatPushNotification({
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
    const result = formatPushNotification({
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
    const result = formatPushNotification({
      accountLabel: "Work",
      spaceTitle: "DM · Sam",
      senderName: "Sam",
      messageText: "",
    });

    expect(result.body).toBe("Sam: (attachment or empty message)");
  });
});

describe("BarkPublisher", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("POSTs JSON to Bark with title, body, badge, and click url", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: async () => "ok",
    });
    vi.stubGlobal("fetch", fetchMock);

    const publisher = new BarkPublisher({
      baseUrl: "https://api.day.app",
      deviceKey: "device-key-abc",
    });

    await publisher.publish({
      title: "[Work] #eng-standup",
      body: "Alice: deploy looks good",
      badge: 3,
      url: "googlechatmulti://space/spaces%2FAAA?accountId=iss%7Csub",
      group: "google-chat",
    });

    expect(fetchMock).toHaveBeenCalledOnce();
    const [url, init] = fetchMock.mock.calls[0]!;
    expect(url).toBe("https://api.day.app/device-key-abc");
    expect(init.method).toBe("POST");
    expect(init.headers["Content-Type"]).toContain("application/json");
    expect(JSON.parse(init.body as string)).toEqual({
      title: "[Work] #eng-standup",
      body: "Alice: deploy looks good",
      badge: 3,
      url: "googlechatmulti://space/spaces%2FAAA?accountId=iss%7Csub",
      group: "google-chat",
      sound: "birdsong",
    });
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });

  it("retries failed deliveries then throws", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce({ ok: false, status: 503, text: async () => "busy" })
      .mockResolvedValueOnce({ ok: false, status: 503, text: async () => "busy" })
      .mockResolvedValueOnce({ ok: false, status: 503, text: async () => "busy" });
    vi.stubGlobal("fetch", fetchMock);

    const publisher = new BarkPublisher({
      baseUrl: "https://api.day.app",
      deviceKey: "k",
      maxRetries: 2,
      retryDelayMs: 0,
    });

    await expect(
      publisher.publish({ title: "t", body: "b" }),
    ).rejects.toThrow(/Bark publish failed/i);

    expect(fetchMock).toHaveBeenCalledTimes(3);
  });
});
