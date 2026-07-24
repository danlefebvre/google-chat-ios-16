import { describe, expect, it } from "vitest";
import { shouldDeliverNotification } from "../src/mutes.js";
import type { MuteConfig } from "../src/mutes.js";

const baseMuteConfig: MuteConfig = {
  mutedAccounts: new Set(),
  mutedSpaces: new Set(),
  quietHours: null,
};

describe("shouldDeliverNotification", () => {
  it("allows delivery when no mutes configured", () => {
    expect(
      shouldDeliverNotification(baseMuteConfig, {
        accountId: "issuer|sub1",
        spaceResourceName: "spaces/abc",
        at: new Date("2026-07-24T14:00:00Z"),
      }),
    ).toBe(true);
  });

  it("blocks muted accounts", () => {
    const config: MuteConfig = {
      ...baseMuteConfig,
      mutedAccounts: new Set(["issuer|sub1"]),
    };

    expect(
      shouldDeliverNotification(config, {
        accountId: "issuer|sub1",
        spaceResourceName: "spaces/abc",
        at: new Date("2026-07-24T14:00:00Z"),
      }),
    ).toBe(false);
  });

  it("blocks muted spaces", () => {
    const config: MuteConfig = {
      ...baseMuteConfig,
      mutedSpaces: new Set(["issuer|sub1:spaces/abc"]),
    };

    expect(
      shouldDeliverNotification(config, {
        accountId: "issuer|sub1",
        spaceResourceName: "spaces/abc",
        at: new Date("2026-07-24T14:00:00Z"),
      }),
    ).toBe(false);
  });

  it("blocks during quiet hours in configured timezone", () => {
    const config: MuteConfig = {
      ...baseMuteConfig,
      quietHours: {
        startHour: 22,
        endHour: 7,
        timeZone: "America/New_York",
      },
    };

    // 11 PM EDT on Jul 24 2026
    expect(
      shouldDeliverNotification(config, {
        accountId: "issuer|sub1",
        spaceResourceName: "spaces/abc",
        at: new Date("2026-07-25T03:00:00Z"),
      }),
    ).toBe(false);

    // 2 PM EDT
    expect(
      shouldDeliverNotification(config, {
        accountId: "issuer|sub1",
        spaceResourceName: "spaces/abc",
        at: new Date("2026-07-24T18:00:00Z"),
      }),
    ).toBe(true);
  });
});
