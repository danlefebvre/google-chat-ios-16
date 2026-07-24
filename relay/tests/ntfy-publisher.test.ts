import { describe, expect, it, vi, beforeEach } from "vitest";
import { NtfyPublisher } from "../src/ntfy/publisher.js";

describe("NtfyPublisher", () => {
  const fetchMock = vi.fn();

  beforeEach(() => {
    fetchMock.mockReset();
    fetchMock.mockResolvedValue({ ok: true, status: 200 });
  });

  it("posts formatted notification to ntfy topic", async () => {
    const publisher = new NtfyPublisher(
      {
        baseUrl: "https://ntfy.sh",
        topic: "secret-topic",
        accessToken: "my-token",
      },
      fetchMock,
    );

    await publisher.publish({
      title: "[Work] #eng-standup",
      body: "Alice: deploy looks good",
      tags: ["google-chat", "work"],
    });

    expect(fetchMock).toHaveBeenCalledOnce();
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe("https://ntfy.sh/secret-topic");
    expect(init.method).toBe("POST");
    expect(init.headers["Title"]).toBe("[Work] #eng-standup");
    expect(init.headers["Authorization"]).toBe("Bearer my-token");
    expect(init.body).toBe("Alice: deploy looks good");
  });

  it("retries on transient failures", async () => {
    fetchMock
      .mockResolvedValueOnce({ ok: false, status: 503 })
      .mockResolvedValueOnce({ ok: true, status: 200 });

    const publisher = new NtfyPublisher(
      { baseUrl: "https://ntfy.sh", topic: "t", accessToken: undefined },
      fetchMock,
    );

    await publisher.publish({ title: "t", body: "b" });

    expect(fetchMock).toHaveBeenCalledTimes(2);
  });
});
