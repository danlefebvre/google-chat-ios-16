import { describe, expect, it } from "vitest";
import { loadConfig } from "../src/config.js";

describe("loadConfig", () => {
  it("loads required ntfy settings from environment", () => {
    const config = loadConfig({
      NTFY_BASE_URL: "https://ntfy.sh",
      NTFY_TOPIC: "secret-topic-abc123",
      NTFY_ACCESS_TOKEN: "tok",
      PORT: "8080",
    });

    expect(config.ntfy.baseUrl).toBe("https://ntfy.sh");
    expect(config.ntfy.topic).toBe("secret-topic-abc123");
    expect(config.ntfy.accessToken).toBe("tok");
    expect(config.port).toBe(8080);
  });

  it("throws when required env vars are missing", () => {
    expect(() => loadConfig({})).toThrow(/NTFY_TOPIC/);
  });
});
