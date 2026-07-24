import { describe, it, expect } from "vitest";
import {
  shouldRenewSubscription,
  subscriptionResourceName,
  subscriptionExpiryFromNow,
  SUBSCRIPTION_TTL_DAYS,
} from "../src/events.js";

describe("subscriptionResourceName", () => {
  it("builds a stable resource name from account id", () => {
    const name = subscriptionResourceName(
      "my-project",
      "https://accounts.google.com|sub-abc",
    );
    expect(name).toBe(
      "projects/my-project/subscriptions/chat-relay-https___accounts_google_com_sub-abc",
    );
  });
});

describe("shouldRenewSubscription", () => {
  it("returns true when expiry is within renew window", () => {
    const now = new Date("2026-07-24T12:00:00Z");
    const expiresAt = new Date("2026-07-25T00:00:00Z"); // < 1 day
    expect(shouldRenewSubscription(expiresAt, now)).toBe(true);
  });

  it("returns false when expiry is far out", () => {
    const now = new Date("2026-07-24T12:00:00Z");
    const expiresAt = new Date("2026-08-01T12:00:00Z");
    expect(shouldRenewSubscription(expiresAt, now)).toBe(false);
  });
});

describe("subscriptionExpiryFromNow", () => {
  it(`defaults to ${SUBSCRIPTION_TTL_DAYS} days`, () => {
    const now = new Date("2026-07-24T12:00:00Z");
    const expiry = subscriptionExpiryFromNow(now);
    expect(expiry.toISOString()).toBe("2026-07-31T12:00:00.000Z");
  });
});
