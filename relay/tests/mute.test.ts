import { describe, it, expect } from "vitest";
import { isMuted, isQuietHours } from "../src/mute.js";

describe("isMuted", () => {
  const mutes = {
    accounts: new Set(["issuer|sub-work"]),
    spaces: new Set(["issuer|sub-work:spaces/AAA"]),
  };

  it("returns true when account is muted", () => {
    expect(isMuted(mutes, "issuer|sub-work", "spaces/BBB")).toBe(true);
  });

  it("returns true when space is muted for that account", () => {
    expect(isMuted(mutes, "issuer|sub-work", "spaces/AAA")).toBe(true);
  });

  it("returns false when neither account nor space is muted", () => {
    expect(isMuted(mutes, "issuer|sub-personal", "spaces/BBB")).toBe(false);
  });
});

describe("isQuietHours", () => {
  it("returns true inside quiet window (same day)", () => {
    const config = { startHour: 22, endHour: 7, timezone: "UTC" };
    const during = new Date("2026-07-24T23:30:00Z");
    expect(isQuietHours(config, during)).toBe(true);
  });

  it("returns false outside quiet window", () => {
    const config = { startHour: 22, endHour: 7, timezone: "UTC" };
    const noon = new Date("2026-07-24T12:00:00Z");
    expect(isQuietHours(config, noon)).toBe(false);
  });

  it("returns false when quiet hours disabled", () => {
    expect(isQuietHours(null, new Date())).toBe(false);
  });
});
