import type { EventsClient } from "./types.js";

export type GoogleEventsClientOptions = {
  projectId: string;
  pubsubTopic: string;
  oauthClientId: string;
  oauthClientSecret: string;
  fetchImpl?: typeof fetch;
};

/**
 * Thin Google Workspace Events + OAuth revoke client.
 * In tests, inject a fake EventsClient instead.
 */
export function createGoogleEventsClient(
  options: GoogleEventsClientOptions,
): EventsClient {
  const fetchImpl = options.fetchImpl ?? fetch;

  return {
    async createSubscription(input) {
      // Exchange refresh token for access token, then create subscription.
      const accessToken = await refreshAccessToken(fetchImpl, {
        clientId: options.oauthClientId,
        clientSecret: options.oauthClientSecret,
        refreshToken: input.refreshToken,
      });

      const expireTime = new Date(
        Date.now() + 7 * 24 * 60 * 60 * 1000,
      ).toISOString();

      const response = await fetchImpl(
        "https://workspaceevents.googleapis.com/v1/subscriptions",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            targetResource: "//cloudresourcemanager.googleapis.com/projects/" +
              options.projectId,
            eventTypes: [
              "google.workspace.chat.message.v1.created",
            ],
            notificationEndpoint: {
              pubsubTopic: options.pubsubTopic,
            },
            payloadOptions: {
              includeResource: true,
            },
            expireTime,
            // Custom attribute so Pub/Sub push can map events → account
            labels: {
              accountId: sanitizeLabel(input.accountId),
            },
          }),
        },
      );

      if (!response.ok) {
        const detail = await response.text();
        throw new Error(
          `createSubscription failed (${response.status}): ${detail}`,
        );
      }

      const body = (await response.json()) as {
        name?: string;
        expireTime?: string;
      };

      return {
        name: body.name ?? `subscriptions/${sanitizeLabel(input.accountId)}`,
        expireTime: body.expireTime ?? expireTime,
      };
    },

    async deleteSubscription(subscriptionName) {
      // Deletion requires an access token; callers should pass a valid one via
      // a richer client in production. For MVP scaffold we best-effort DELETE.
      const response = await fetchImpl(
        `https://workspaceevents.googleapis.com/v1/${subscriptionName}`,
        { method: "DELETE" },
      );
      if (!response.ok && response.status !== 404) {
        const detail = await response.text();
        throw new Error(
          `deleteSubscription failed (${response.status}): ${detail}`,
        );
      }
    },

    async revokeToken(refreshToken) {
      const response = await fetchImpl(
        "https://oauth2.googleapis.com/revoke",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: new URLSearchParams({ token: refreshToken }).toString(),
        },
      );
      if (!response.ok && response.status !== 400) {
        const detail = await response.text();
        throw new Error(`revokeToken failed (${response.status}): ${detail}`);
      }
    },
  };
}

async function refreshAccessToken(
  fetchImpl: typeof fetch,
  input: { clientId: string; clientSecret: string; refreshToken: string },
): Promise<string> {
  const response = await fetchImpl("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: input.clientId,
      client_secret: input.clientSecret,
      refresh_token: input.refreshToken,
      grant_type: "refresh_token",
    }).toString(),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`token refresh failed (${response.status}): ${detail}`);
  }

  const body = (await response.json()) as { access_token?: string };
  if (!body.access_token) {
    throw new Error("token refresh returned no access_token");
  }
  return body.access_token;
}

function sanitizeLabel(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 63);
}
