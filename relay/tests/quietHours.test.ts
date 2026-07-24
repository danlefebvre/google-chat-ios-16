import { describe, expect, it } from "vitest";
import { isInQuietHours } from "../src/events.js";

describe("isInQuietHours", () => {
  it("handles wrap-around windows", () => {
    expect(
      isInQuietHours(new Date("2026-07-24T23:00:00Z"), {
        startHour: 22,
        endHour: 7,
        timeZone: "UTC",
      }),
    ).toBe(true);
    expect(
      isInQuietHours(new Date("2026-07-24T06:00:00Z"), {
        startHour: 22,
        endHour: 7,
        timeZone: "UTC",
      }),
    ).toBe(true);
    expect(
      isInQuietHours(new Date("2026-07-24T12:00:00Z"), {
        startHour: 22,
        endHour: 7,
        timeZone: "UTC",
      }),
    ).toBe(false);
  });

  it("handles same-day windows", () => {
    expect(
      isInQuietHours(new Date("2026-07-24T14:00:00Z"), {
        startHour: 13,
        endHour: 15,
        timeZone: "UTC",
      }),
    ).toBe(true);
    expect(
      isInQuietHours(new Date("2026-07-24T16:00:00Z"), {
        startHour: 13,
        endHour: 15,
        timeZone: "UTC",
      }),
    ).toBe(false);
  });
});
