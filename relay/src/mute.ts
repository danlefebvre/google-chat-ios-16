import type { MuteConfig, QuietHoursConfig } from "./types.js";

export function isMuted(
  mutes: MuteConfig,
  accountId: string,
  spaceName: string,
): boolean {
  if (mutes.accounts.has(accountId)) {
    return true;
  }
  return mutes.spaces.has(`${accountId}:${spaceName}`);
}

export function isQuietHours(
  config: QuietHoursConfig | null,
  at: Date,
): boolean {
  if (!config) {
    return false;
  }

  const hour = getHourInTimezone(at, config.timezone);

  if (config.startHour < config.endHour) {
    return hour >= config.startHour && hour < config.endHour;
  }

  // Overnight window (e.g. 22 → 7)
  return hour >= config.startHour || hour < config.endHour;
}

function getHourInTimezone(date: Date, timezone: string): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    hour: "numeric",
    hour12: false,
  });
  const parts = formatter.formatToParts(date);
  const hourPart = parts.find((p) => p.type === "hour");
  return Number(hourPart?.value ?? date.getUTCHours());
}
