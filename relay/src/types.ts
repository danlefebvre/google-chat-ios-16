export interface RelayAccount {
  accountId: string;
  label: string;
  refreshToken: string;
  subscriptionName: string;
  mutedSpaces: string[];
  muted: boolean;
}

export interface NtfyConfig {
  baseUrl: string;
  topic: string;
  accessToken?: string;
}

export interface NotificationPayload {
  title: string;
  body: string;
}

export interface QuietHours {
  startHour: number;
  endHour: number;
  timezone: string;
}

export interface MuteConfig {
  mutedAccounts: string[];
  mutedSpaces: string[];
  quietHours: QuietHours | null;
}

export interface FormatNotificationInput {
  accountLabel: string;
  spaceTitle: string;
  senderName: string;
  messageText: string;
}

export function makeAccountId(issuer: string, sub: string): string {
  return `${issuer}|${sub}`;
}

export function makeSpaceMuteKey(accountId: string, spaceName: string): string {
  return `${accountId}:${spaceName}`;
}
