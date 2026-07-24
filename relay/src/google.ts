import type { EventsClient, SubscriptionHandle } from "./types.js";

export type GoogleEventsClientOptions = {
  projectId: string;
  pubsubTopic: string;
  oauthClientId: string;
  oauthClientSecret: string;
  fetchImpl?: typeof fetch;
};

/** Workspace Events max lifetime with includeResource (no DWD) is ~4 hours. */
const SUBSCRIPTION_TTL_SECONDS = 4 * 60 * 60;
const GOOGLE_FETCH_TIMEOUT_MS = 15_000;

/**
 * Thin Google Workspace Events + OAuth revoke client.
 * In tests, inject a fake EventsClient instead.
 */
export function createGoogleEventsClient(
  options: GoogleEventsClientOptions,
): EventsClient {
  const rawFetch = options.fetchImpl ?? fetch;
  const fetchImpl: typeof fetch = (input, init) =>
    fetchWithTimeout(rawFetch, input, init, GOOGLE_FETCH_TIMEOUT_MS);

  return {
    async createSubscription(input) {
      const accessToken = await refreshAccessToken(fetchImpl, {
        clientId: options.oauthClientId,
        clientSecret: options.oauthClientSecret,
        refreshToken: input.refreshToken,
      });

      const ttl = `${SUBSCRIPTION_TTL_SECONDS}s`;
      const fallbackExpire = new Date(
        Date.now() + SUBSCRIPTION_TTL_SECONDS * 1000,
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
            // Chat user-scoped target (all spaces the caller can access).
            targetResource: "//chat.googleapis.com/spaces/-",
            eventTypes: ["google.workspace.chat.message.v1.created"],
            notificationEndpoint: {
              pubsubTopic: options.pubsubTopic,
            },
            payloadOptions: {
              includeResource: true,
            },
            ttl,
          }),
        },
      );

      if (!response.ok) {
        const detail = await response.text();
        throw new Error(
          `createSubscription failed (${response.status}): ${detail}`,
        );
      }

      const subscription = await resolveSubscriptionOperation(
        fetchImpl,
        accessToken,
        await response.json(),
      );

      return {
        name:
          subscription.name ??
          `subscriptions/${sanitizeLabel(input.accountId)}`,
        expireTime: subscription.expireTime ?? fallbackExpire,
      };
    },

    async renewSubscription(input) {
      const accessToken = await refreshAccessToken(fetchImpl, {
        clientId: options.oauthClientId,
        clientSecret: options.oauthClientSecret,
        refreshToken: input.refreshToken,
      });

      const expireTime = new Date(
        Date.now() + SUBSCRIPTION_TTL_SECONDS * 1000,
      ).toISOString();

      const response = await fetchImpl(
        `https://workspaceevents.googleapis.com/v1/${input.subscriptionName}?updateMask=expireTime`,
        {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ expireTime }),
        },
      );

      if (!response.ok) {
        const detail = await response.text();
        throw new Error(
          `renewSubscription failed (${response.status}): ${detail}`,
        );
      }

      const subscription = await resolveSubscriptionOperation(
        fetchImpl,
        accessToken,
        await response.json(),
      );

      return {
        name: subscription.name ?? input.subscriptionName,
        expireTime: subscription.expireTime ?? expireTime,
      };
    },

    async deleteSubscription(input) {
      const accessToken = await refreshAccessToken(fetchImpl, {
        clientId: options.oauthClientId,
        clientSecret: options.oauthClientSecret,
        refreshToken: input.refreshToken,
      });

      const response = await fetchImpl(
        `https://workspaceevents.googleapis.com/v1/${input.subscriptionName}`,
        {
          method: "DELETE",
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        },
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

type OperationBody = {
  name?: string;
  done?: boolean;
  response?: {
    name?: string;
    expireTime?: string;
  };
  error?: { message?: string };
};

async function resolveSubscriptionOperation(
  fetchImpl: typeof fetch,
  accessToken: string,
  body: unknown,
): Promise<Partial<SubscriptionHandle>> {
  const operation = body as OperationBody;

  // Direct Subscription JSON (some clients/mocks) — treat as resolved.
  if (operation.response?.name || (operation.name?.startsWith("subscriptions/") && operation.done !== false && !operation.name?.startsWith("operations/"))) {
    if (operation.response) {
      return {
        name: operation.response.name,
        expireTime: operation.response.expireTime,
      };
    }
    if (operation.name?.startsWith("subscriptions/")) {
      return {
        name: operation.name,
        expireTime: (body as { expireTime?: string }).expireTime,
      };
    }
  }

  if (operation.error?.message) {
    throw new Error(`subscription operation failed: ${operation.error.message}`);
  }

  if (operation.done && operation.response) {
    return {
      name: operation.response.name,
      expireTime: operation.response.expireTime,
    };
  }

  if (operation.name?.startsWith("operations/")) {
    return pollOperation(fetchImpl, accessToken, operation.name);
  }

  // Fallback: body itself looks like a Subscription.
  const direct = body as { name?: string; expireTime?: string };
  return { name: direct.name, expireTime: direct.expireTime };
}

async function pollOperation(
  fetchImpl: typeof fetch,
  accessToken: string,
  operationName: string,
  attempts = 10,
): Promise<Partial<SubscriptionHandle>> {
  for (let i = 0; i < attempts; i += 1) {
    const response = await fetchImpl(
      `https://workspaceevents.googleapis.com/v1/${operationName}`,
      {
        headers: { Authorization: `Bearer ${accessToken}` },
      },
    );
    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`operations.get failed (${response.status}): ${detail}`);
    }
    const body = (await response.json()) as OperationBody;
    if (body.error?.message) {
      throw new Error(`subscription operation failed: ${body.error.message}`);
    }
    if (body.done) {
      return {
        name: body.response?.name,
        expireTime: body.response?.expireTime,
      };
    }
    await sleep(250);
  }
  throw new Error(`subscription operation timed out: ${operationName}`);
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

export type AccountOwnershipInput = {
  accountId: string;
  email: string;
  refreshToken: string;
};

export type AccountOwnershipVerifier = (
  input: AccountOwnershipInput,
) => Promise<boolean>;

/**
 * Confirm a Google refresh token belongs to the claimed accountId (`issuer|sub`)
 * and email before allowing relay registration.
 */
export function createGoogleAccountOwnershipVerifier(options: {
  oauthClientId: string;
  oauthClientSecret: string;
  fetchImpl?: typeof fetch;
}): AccountOwnershipVerifier {
  const rawFetch = options.fetchImpl ?? fetch;
  const fetchImpl: typeof fetch = (input, init) =>
    fetchWithTimeout(rawFetch, input, init, GOOGLE_FETCH_TIMEOUT_MS);
  return async (input) => {
    try {
      const accessToken = await refreshAccessToken(fetchImpl, {
        clientId: options.oauthClientId,
        clientSecret: options.oauthClientSecret,
        refreshToken: input.refreshToken,
      });
      const response = await fetchImpl(
        "https://openidconnect.googleapis.com/v1/userinfo",
        {
          headers: { Authorization: `Bearer ${accessToken}` },
        },
      );
      if (!response.ok) {
        return false;
      }
      const profile = (await response.json()) as {
        sub?: string;
        email?: string;
        iss?: string;
      };
      if (!profile.sub || !profile.email) {
        return false;
      }
      const separator = input.accountId.indexOf("|");
      if (separator <= 0) {
        return false;
      }
      const issuer = input.accountId.slice(0, separator);
      const subject = input.accountId.slice(separator + 1);
      if (!subject || profile.sub !== subject) {
        return false;
      }
      if (profile.email.toLowerCase() !== String(input.email).toLowerCase()) {
        return false;
      }
      // Accept Google's issuer forms when present on the userinfo payload.
      if (
        profile.iss &&
        profile.iss !== issuer &&
        profile.iss !== "https://accounts.google.com" &&
        issuer !== "https://accounts.google.com" &&
        profile.iss !== "accounts.google.com"
      ) {
        return false;
      }
      return true;
    } catch {
      return false;
    }
  };
}

function sanitizeLabel(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 63);
}

async function fetchWithTimeout(
  fetchImpl: typeof fetch,
  input: Parameters<typeof fetch>[0],
  init: Parameters<typeof fetch>[1],
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const parentSignal = init?.signal;
    if (parentSignal) {
      if (parentSignal.aborted) {
        controller.abort();
      } else {
        parentSignal.addEventListener("abort", () => controller.abort(), {
          once: true,
        });
      }
    }
    return await fetchImpl(input, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
