import { describe, it, expect } from "vitest";
import {
  buildSubscriptionRequest,
  MAX_TTL_WITH_RESOURCE_DATA_SECONDS,
} from "../src/workspace-events.js";

describe("buildSubscriptionRequest", () => {
  it("builds Workspace Events subscription for chat messages", () => {
    const req = buildSubscriptionRequest({
      projectId: "my-project",
      pubsubTopic: "projects/my-project/topics/chat-events",
      accountId: "https://accounts.google.com|user1",
      ttlSeconds: 86400,
    });

    expect(req.targetResource).toBe("//chat.googleapis.com/spaces/-");
    expect(req.eventTypes).toContain("google.workspace.chat.message.v1.created");
    expect(req.notificationEndpoint.pubsubTopic).toBe(
      "projects/my-project/topics/chat-events",
    );
    expect(req.payloadOptions.includeResource).toBe(true);
    expect(req.ttl).toBe(`${MAX_TTL_WITH_RESOURCE_DATA_SECONDS}s`);
  });
});
