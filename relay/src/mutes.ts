export interface QuietHours {
  startHour: number;
  endHour: number;
  timeZone: string;
}

export interface MuteConfig {
  mutedAccounts: Set<string>;
  mutedSpaces: Set<string>;
  quietHours: QuietHours | null;
}

export interface DeliveryContext {
  accountId: string;
  spaceResourceName: string;
  at: Date;
}

function getHourInTimeZone(date: Date, timeZone: string): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    hour12: false,
    timeZone,
  });
  return Number(formatter.format(date));
}

function isWithinQuietHours(hours: QuietHours, at: Date): boolean {
  const hour = getHourInTimeZone(at, hours.timeZone);

  if (hours.startHour === hours.endHour) {
    return false;
  }

  if (hours.startHour < hours.endHour) {
    return hour >= hours.startHour && hour < hours.endHour;
  }

  return hour >= hours.startHour || hour < hours.endHour;
}

export function shouldDeliverNotification(
  config: MuteConfig,
  context: DeliveryContext,
): boolean {
  if (config.mutedAccounts.has(context.accountId)) {
    return false;
  }

  const spaceKey = `${context.accountId}:${context.spaceResourceName}`;
  if (config.mutedSpaces.has(spaceKey)) {
    return false;
  }

  if (config.quietHours && isWithinQuietHours(config.quietHours, context.at)) {
    return false;
  }

  return true;
}

export function spaceMuteKey(
  accountId: string,
  spaceResourceName: string,
): string {
  return `${accountId}:${spaceResourceName}`;
}
