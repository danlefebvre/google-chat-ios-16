import { describe, it, expect } from "vitest";
import { shouldNotify } from "../src/mutes.js";

describe("shouldNotify", () => {
  const base = {
    accountId: "issuer|sub123",
    spaceName: "spaces/AAA",
    now: new Date("2026-07-24T14:00:00Z"),
  };

  it("allows notification when no mutes configured", () => {
    expect(shouldNotify(base, { mutedAccounts: [], mutedSpaces: [], quietHours: null })).toBe(true);
  });

  it("blocks muted account", () => {
    expect(
      shouldNotify(base, {
        mutedAccounts: ["issuer|sub123"],
        mutedSpaces: [],
        quietHours: null,
      }),
    ).toBe(false);
  });

  it("blocks muted space", () => {
    expect(
      shouldNotify(base, {
        mutedAccounts: [],
        mutedSpaces: ["issuer|sub123:spaces/AAA"],
        quietHours: null,
      }),
    ).toBe(false);
  });

  it("blocks during quiet hours", () => {
    expect(
      shouldNotify(
        { ...base, now: new Date("2026-07-24T23:00:00Z") },
        {
          mutedAccounts: [],
          mutedSpaces: [],
          quietHours: { startHour: 22, endHour: 7, timezone: "UTC" },
        },
      ),
    ).toBe(false);
  });

  it("allows outside quiet hours", () => {
    expect(
      shouldNotify(
        { ...base, now: new Date("2026-07-24T10:00:00Z") },
        {
          mutedAccounts: [],
          mutedSpaces: [],
          quietHours: { startHour: 22, endHour: 7, timezone: "UTC" },
        },
      ),
    ).toBe(true);
  });
});
