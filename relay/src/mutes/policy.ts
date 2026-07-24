export type QuietHours = {
  startHour: number;
  endHour: number;
  timezone: string;
};

type ShouldNotifyInput = {
  accountId: string;
  spaceResourceName: string;
  mutedAccounts: Set<string>;
  mutedSpaces: Set<string>;
  quietHours: QuietHours | null;
  now: Date;
};

export function shouldNotify(input: ShouldNotifyInput): boolean {
  if (input.mutedAccounts.has(input.accountId)) {
    return false;
  }

  const spaceKey = `${input.accountId}:${input.spaceResourceName}`;
  if (input.mutedSpaces.has(spaceKey) || input.mutedSpaces.has(input.spaceResourceName)) {
    return false;
  }

  if (input.quietHours && isWithinQuietHours(input.now, input.quietHours)) {
    return false;
  }

  return true;
}

function isWithinQuietHours(now: Date, quietHours: QuietHours): boolean {
  const hour = now.getUTCHours();
  const { startHour, endHour } = quietHours;

  if (startHour === endHour) {
    return false;
  }

  if (startHour < endHour) {
    return hour >= startHour && hour < endHour;
  }

  return hour >= startHour || hour < endHour;
}
