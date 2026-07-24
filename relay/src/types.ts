export type AccountRecord = {
  accountId: string;
  email: string;
  label: string;
  encryptedRefreshToken: string;
  subscriptionName: string | null;
  subscriptionExpireTime: string | null;
  ntfyBindingActive: boolean;
  muted: boolean;
  mutedSpaces: string[];
  createdAt: string;
};

export type QuietHours = {
  startHour: number;
  endHour: number;
  timeZone: string;
};

export type NtfyConfig = {
  baseUrl: string;
  topic: string;
  accessToken: string;
};

export type ParsedChatEvent = {
  accountId: string;
  accountLabel: string;
  spaceName: string;
  spaceTitle: string;
  messageName: string;
  senderName: string;
  messageText: string;
  createTime: string;
  eventType: "message.created";
};

export type SubscriptionHandle = {
  name: string;
  expireTime: string;
};

export type EventsClient = {
  createSubscription: (input: {
    accountId: string;
    refreshToken: string;
  }) => Promise<SubscriptionHandle>;
  renewSubscription: (input: {
    subscriptionName: string;
    refreshToken: string;
  }) => Promise<SubscriptionHandle>;
  deleteSubscription: (input: {
    subscriptionName: string;
    refreshToken: string;
  }) => Promise<void>;
  revokeToken: (refreshToken: string) => Promise<void>;
};

export type TokenCrypto = {
  encrypt: (plain: string) => string;
  decrypt: (cipher: string) => string;
};
