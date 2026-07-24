import { describe, it, expect, vi, beforeEach } from "vitest";
import { publishToNtfy } from "../src/ntfy.js";

describe("publishToNtfy", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("POSTs formatted notification to ntfy.sh topic", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
    });
    vi.stubGlobal("fetch", fetchMock);

    await publishToNtfy(
      {
        baseUrl: "https://ntfy.sh",
        topic: "secret-topic-abc123",
        accessToken: "tok123",
      },
      { title: "[Work] #eng-standup", body: "Alice: deploy looks good" },
    );

    expect(fetchMock).toHaveBeenCalledOnce();
    const [url, options] = fetchMock.mock.calls[0];
    expect(url).toBe("https://ntfy.sh/secret-topic-abc123");
    expect(options.method).toBe("POST");
    expect(options.headers["Title"]).toBe("[Work] #eng-standup");
    expect(options.headers["Authorization"]).toBe("Bearer tok123");
    expect(options.body).toBe("Alice: deploy looks good");
  });

  it("throws when ntfy returns non-2xx", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: false, status: 429, statusText: "Too Many Requests" }),
    );

    await expect(
      publishToNtfy(
        { baseUrl: "https://ntfy.sh", topic: "t", accessToken: undefined },
        { title: "t", body: "b" },
      ),
    ).rejects.toThrow(/429/);
  });

  it("passes an abort timeout to fetch", async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200 });
    vi.stubGlobal("fetch", fetchMock);

    await publishToNtfy(
      { baseUrl: "https://ntfy.sh", topic: "t", accessToken: undefined },
      { title: "t", body: "b" },
    );

    const options = fetchMock.mock.calls[0][1];
    expect(options.signal).toBeInstanceOf(AbortSignal);
  });
});
