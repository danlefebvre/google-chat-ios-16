import { describe, expect, it, vi } from "vitest";
import {
  createGoogleEventsClient,
  extractAlreadyExistsSubscriptionName,
} from "../src/google.js";

describe("extractAlreadyExistsSubscriptionName", () => {
  it("reads current_subscription from ErrorInfo metadata", () => {
    const detail = JSON.stringify({
      error: {
        code: 409,
        message: "Subscription associated with the resource already exists.",
        status: "ALREADY_EXISTS",
        details: [
          {
            "@type": "type.googleapis.com/google.rpc.ErrorInfo",
            reason: "SUBSCRIPTION_ALREADY_EXISTS",
            domain: "googleapis.com",
            metadata: {
              service: "workspaceevents.googleapis.com",
              current_subscription:
                "subscriptions/chat-spaces-czotOjExNzc5MjA1MTUwOTA0NTQ0MzA3NzoxMDc5MjIwNTgzNDU4ODI5OTMxMDU",
            },
          },
        ],
      },
    });
    expect(extractAlreadyExistsSubscriptionName(detail)).toBe(
      "subscriptions/chat-spaces-czotOjExNzc5MjA1MTUwOTA0NTQ0MzA3NzoxMDc5MjIwNTgzNDU4ODI5OTMxMDU",
    );
  });

  it("returns null when metadata is missing", () => {
    expect(extractAlreadyExistsSubscriptionName(`{"error":{"code":409}}`)).toBeNull();
  });
});

describe("createGoogleEventsClient.createSubscription", () => {
  it("deletes orphan subscription on 409 then retries create", async () => {
    const calls: Array<{ url: string; method: string }> = [];
    const fetchImpl = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      const method = init?.method ?? "GET";
      calls.push({ url, method });

      if (url.includes("oauth2.googleapis.com/token")) {
        return new Response(JSON.stringify({ access_token: "at" }), { status: 200 });
      }
      if (url.endsWith("/v1/subscriptions") && method === "POST") {
        const postCount = calls.filter(
          (c) => c.url.endsWith("/v1/subscriptions") && c.method === "POST",
        ).length;
        if (postCount === 1) {
          return new Response(
            JSON.stringify({
              error: {
                code: 409,
                details: [
                  {
                    metadata: {
                      current_subscription: "subscriptions/orphan-1",
                    },
                  },
                ],
              },
            }),
            { status: 409 },
          );
        }
        return new Response(
          JSON.stringify({
            name: "subscriptions/fresh-1",
            expireTime: "2026-08-01T00:00:00Z",
            done: true,
          }),
          { status: 200 },
        );
      }
      if (url.includes("subscriptions/orphan-1") && method === "DELETE") {
        return new Response(null, { status: 200 });
      }
      return new Response(`unexpected ${method} ${url}`, { status: 500 });
    }) as unknown as typeof fetch;

    const client = createGoogleEventsClient({
      projectId: "p",
      pubsubTopic: "projects/p/topics/t",
      oauthClientId: "cid",
      fetchImpl,
    });

    const sub = await client.createSubscription({
      accountId: "https://accounts.google.com|1",
      refreshToken: "rt",
    });

    expect(sub.name).toBe("subscriptions/fresh-1");
    expect(calls.some((c) => c.method === "DELETE" && c.url.includes("orphan-1"))).toBe(
      true,
    );
    expect(
      calls.filter((c) => c.url.endsWith("/v1/subscriptions") && c.method === "POST"),
    ).toHaveLength(2);
  });
});
