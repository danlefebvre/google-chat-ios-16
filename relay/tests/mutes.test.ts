import { describe, expect, it } from "vitest";
import { shouldNotify } from "../src/mutes/policy.js";

describe("shouldNotify", () => {
  const base = {
    accountId: "issuer|sub",
    spaceResourceName: "spaces/AAA",
    mutedAccounts: new Set<string>(),
    mutedSpaces: new Set<string>(),
    quietHours: null as { startHour: number; endHour: number; timezone: string } | null,
    now: new Date("2026-07-24T14:00:00Z"),
  };

  it("allows notification by default", () => {
    expect(shouldNotify(base)).toBe(true);
  });

  it("blocks muted accounts", () => {
    expect(
      shouldNotify({
        ...base,
        mutedAccounts: new Set(["issuer|sub"]),
      }),
    ).toBe(false);
  });

  it("blocks muted spaces", () => {
    expect(
      shouldNotify({
        ...base,
        mutedSpaces: new Set(["issuer|sub:spaces/AAA"]),
      }),
    ).toBe(false);
  });

  it("blocks during quiet hours", () => {
    expect(
      shouldNotify({
        ...base,
        quietHours: { startHour: 22, endHour: 7, timezone: "UTC" },
        now: new Date("2026-07-24T23:00:00Z"),
      }),
    ).toBe(false);
  });
});
