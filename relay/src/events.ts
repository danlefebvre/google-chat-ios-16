/**
 * Workspace Events subscription helpers.
 * Full Google API integration requires credentials at runtime;
 * these functions encapsulate subscription naming and TTL refresh policy.
 */

export const SUBSCRIPTION_TTL_DAYS = 7;
export const RENEW_BEFORE_DAYS = 1;

export function subscriptionResourceName(
  projectId: string,
  accountId: string,
): string {
  const safeId = accountId.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 48);
  return `projects/${projectId}/subscriptions/chat-relay-${safeId}`;
}

export function shouldRenewSubscription(expiresAt: Date, now = new Date()): boolean {
  const msUntilExpiry = expiresAt.getTime() - now.getTime();
  const renewThresholdMs = RENEW_BEFORE_DAYS * 24 * 60 * 60 * 1000;
  return msUntilExpiry <= renewThresholdMs;
}

export function subscriptionExpiryFromNow(now = new Date()): Date {
  const expiry = new Date(now);
  expiry.setDate(expiry.getDate() + SUBSCRIPTION_TTL_DAYS);
  return expiry;
}
