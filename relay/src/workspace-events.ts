export interface SubscriptionRequestInput {
  projectId: string;
  pubsubTopic: string;
  accountId: string;
  ttlSeconds: number;
}

export interface SubscriptionRequest {
  targetResource: string;
  eventTypes: string[];
  notificationEndpoint: { pubsubTopic: string };
  payloadOptions: { includeResource: boolean };
  ttl: string;
}

/** Max TTL when includeResource is true (without domain-wide delegation). */
export const MAX_TTL_WITH_RESOURCE_DATA_SECONDS = 4 * 60 * 60;

export function extractUserId(accountId: string): string {
  const parts = accountId.split("|");
  if (parts.length < 2) {
    throw new Error(`invalid accountId: ${accountId}`);
  }
  return parts[1];
}

export function buildSubscriptionRequest(
  input: SubscriptionRequestInput,
): SubscriptionRequest {
  // Message events require a Chat spaces target; `spaces/-` covers all spaces
  // for the authorizing user. Resource data is required for ntfy previews.
  const ttlSeconds = Math.min(input.ttlSeconds, MAX_TTL_WITH_RESOURCE_DATA_SECONDS);

  return {
    targetResource: "//chat.googleapis.com/spaces/-",
    eventTypes: ["google.workspace.chat.message.v1.created"],
    notificationEndpoint: { pubsubTopic: input.pubsubTopic },
    payloadOptions: { includeResource: true },
    ttl: `${ttlSeconds}s`,
  };
}

export async function renewSubscription(
  subscriptionName: string,
  ttlSeconds: number,
  renewFn: (name: string, ttl: string) => Promise<void>,
): Promise<void> {
  const clamped = Math.min(ttlSeconds, MAX_TTL_WITH_RESOURCE_DATA_SECONDS);
  await renewFn(subscriptionName, `${clamped}s`);
}
