export interface NtfyConfig {
  server: string;
  topic: string;
  accessToken?: string;
}

export interface GoogleConfig {
  projectId?: string;
  clientId?: string;
  clientSecret?: string;
}

export interface PubSubConfig {
  subscription?: string;
}

export interface RelayConfig {
  ntfy: NtfyConfig;
  google: GoogleConfig;
  pubsub: PubSubConfig;
  port: number;
  quietHours?: QuietHoursConfig | null;
}

export interface QuietHoursConfig {
  startHour: number;
  endHour: number;
  timezone: string;
}

export interface MuteConfig {
  accounts: Set<string>;
  spaces: Set<string>;
}

export interface AccountBinding {
  accountId: string;
  label: string;
  refreshToken: string;
  subscriptionName: string;
}

export interface NtfyNotification {
  title: string;
  body: string;
  tags?: string[];
  click?: string;
  priority?: number;
}

export interface ChatMessageEvent {
  spaceName: string;
  spaceTitle: string;
  senderName: string;
  messageText: string;
  messageName: string;
  createTime: string;
}

export interface HandleResult {
  published: boolean;
  reason: string;
}

export interface RelayDeps {
  publish: (notification: NtfyNotification) => Promise<void>;
  mutes: MuteConfig;
  quietHours: QuietHoursConfig | null;
  accounts: Map<string, AccountBinding>;
  now?: () => Date;
}

export interface AppConfig extends RelayConfig {
  version: string;
}
