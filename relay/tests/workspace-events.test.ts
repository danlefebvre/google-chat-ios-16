import { describe, it, expect } from "vitest";
import { buildSubscriptionRequest } from "../src/workspace-events.js";

describe("buildSubscriptionRequest", () => {
  it("builds Workspace Events subscription for chat messages", () => {
    const req = buildSubscriptionRequest({
      projectId: "my-project",
      pubsubTopic: "projects/my-project/topics/chat-events",
      accountId: "https://accounts.google.com|user1",
      ttlSeconds: 86400,
    });

    expect(req.targetResource).toBe("//chat.googleapis.com/users/user1");
    expect(req.eventTypes).toContain("google.workspace.chat.message.v1.created");
    expect(req.notificationEndpoint.pubsubTopic).toBe(
      "projects/my-project/topics/chat-events",
    );
    expect(req.ttl).toBe("86400s");
  });
});
