import { describe, it, expect } from "vitest";
import { loadConfig } from "../src/config.js";

describe("loadConfig", () => {
  const baseEnv: Record<string, string> = {
    NTFY_SERVER: "https://ntfy.sh",
    NTFY_TOPIC: "test-secret-topic",
    NTFY_ACCESS_TOKEN: "tok123",
    PORT: "8080",
    GOOGLE_CLOUD_PROJECT: "my-project",
    PUBSUB_SUBSCRIPTION: "chat-events-sub",
  };

  it("parses required env vars", () => {
    const config = loadConfig(baseEnv);
    expect(config.ntfy.server).toBe("https://ntfy.sh");
    expect(config.ntfy.topic).toBe("test-secret-topic");
    expect(config.ntfy.accessToken).toBe("tok123");
    expect(config.port).toBe(8080);
    expect(config.google.projectId).toBe("my-project");
    expect(config.pubsub.subscription).toBe("chat-events-sub");
  });

  it("strips trailing slash from ntfy server", () => {
    const config = loadConfig({ ...baseEnv, NTFY_SERVER: "https://ntfy.sh/" });
    expect(config.ntfy.server).toBe("https://ntfy.sh");
  });

  it("throws when required vars are missing", () => {
    expect(() => loadConfig({})).toThrow(/NTFY_TOPIC/);
    expect(() => loadConfig({ NTFY_TOPIC: "x" })).toThrow(/NTFY_SERVER/);
  });

  it("defaults port to 8080 when unset", () => {
    const { PORT: _, ...rest } = baseEnv;
    const config = loadConfig(rest);
    expect(config.port).toBe(8080);
  });
});
