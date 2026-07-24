import { describe, expect, it } from "vitest";
import { subscriptionNeedsRenewal } from "../src/subscriptions.js";

describe("subscriptionNeedsRenewal", () => {
  it("returns true when expiry is within the renewal window", () => {
    const now = new Date("2026-07-24T12:00:00Z");
    const expiresAt = new Date("2026-07-24T13:00:00Z");
    expect(subscriptionNeedsRenewal(expiresAt, now, 2)).toBe(true);
  });

  it("returns false when expiry is far in the future", () => {
    const now = new Date("2026-07-24T12:00:00Z");
    const expiresAt = new Date("2026-07-30T12:00:00Z");
    expect(subscriptionNeedsRenewal(expiresAt, now, 2)).toBe(false);
  });
});
