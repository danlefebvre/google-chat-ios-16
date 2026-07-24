import { describe, expect, it } from "vitest";
import { subscriptionNeedsRenewal } from "../src/subscriptions/lifecycle.js";

describe("subscriptionNeedsRenewal", () => {
  it("returns true when expiry is within renewal window", () => {
    const now = new Date("2026-07-24T12:00:00Z");
    const expireTime = new Date("2026-07-24T13:00:00Z");

    expect(subscriptionNeedsRenewal(expireTime, now, 2 * 60 * 60 * 1000)).toBe(true);
  });

  it("returns false when expiry is far in the future", () => {
    const now = new Date("2026-07-24T12:00:00Z");
    const expireTime = new Date("2026-07-30T12:00:00Z");

    expect(subscriptionNeedsRenewal(expireTime, now, 2 * 60 * 60 * 1000)).toBe(false);
  });
});
