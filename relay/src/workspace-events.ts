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
  const userId = extractUserId(input.accountId);

  return {
    targetResource: `//chat.googleapis.com/users/${userId}`,
    eventTypes: ["google.workspace.chat.message.v1.created"],
    notificationEndpoint: { pubsubTopic: input.pubsubTopic },
    payloadOptions: { includeResource: false },
    ttl: `${input.ttlSeconds}s`,
  };
}

export async function renewSubscription(
  subscriptionName: string,
  ttlSeconds: number,
  renewFn: (name: string, ttl: string) => Promise<void>,
): Promise<void> {
  await renewFn(subscriptionName, `${ttlSeconds}s`);
}
