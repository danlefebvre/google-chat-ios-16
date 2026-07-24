import type { MuteConfig } from "./types.js";
import { makeSpaceMuteKey } from "./types.js";

interface ShouldNotifyInput {
  accountId: string;
  spaceName: string;
  now: Date;
}

function getHourInTimezone(date: Date, timezone: string): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    hour12: false,
    timeZone: timezone,
  });
  return Number(formatter.format(date));
}

function isInQuietHours(now: Date, startHour: number, endHour: number, timezone: string): boolean {
  const hour = getHourInTimezone(now, timezone);

  if (startHour === endHour) {
    return false;
  }

  if (startHour < endHour) {
    return hour >= startHour && hour < endHour;
  }

  return hour >= startHour || hour < endHour;
}

export function shouldNotify(input: ShouldNotifyInput, config: MuteConfig): boolean {
  if (config.mutedAccounts.includes(input.accountId)) {
    return false;
  }

  const spaceKey = makeSpaceMuteKey(input.accountId, input.spaceName);
  if (config.mutedSpaces.includes(spaceKey)) {
    return false;
  }

  if (config.quietHours) {
    const { startHour, endHour, timezone } = config.quietHours;
    if (isInQuietHours(input.now, startHour, endHour, timezone)) {
      return false;
    }
  }

  return true;
}
