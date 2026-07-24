export function subscriptionNeedsRenewal(
  expiresAt: Date,
  now: Date,
  renewalWindowHours: number,
): boolean {
  const windowMs = renewalWindowHours * 60 * 60 * 1000;
  return expiresAt.getTime() - now.getTime() <= windowMs;
}
