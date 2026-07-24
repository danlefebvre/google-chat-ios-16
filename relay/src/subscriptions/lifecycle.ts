export function subscriptionNeedsRenewal(
  expireTime: Date,
  now: Date,
  renewalWindowMs: number,
): boolean {
  return expireTime.getTime() - now.getTime() <= renewalWindowMs;
}
