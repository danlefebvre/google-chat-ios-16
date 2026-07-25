export type BarkPublishInput = {
  title: string;
  body: string;
  /** Deep link / URL opened when the notification is tapped. */
  url?: string;
  /** Absolute badge number shown on the Bark app icon. */
  badge?: number;
  /** Notification Center group. */
  group?: string;
  sound?: string;
  timeoutMs?: number;
};

export type FormatNotificationInput = {
  accountLabel: string;
  spaceTitle: string;
  senderName: string;
  messageText: string;
};

export function formatPushNotification(input: FormatNotificationInput): {
  title: string;
  body: string;
} {
  const text =
    input.messageText.trim().length > 0
      ? input.messageText.trim()
      : "(attachment or empty message)";

  return {
    title: `[${input.accountLabel}] ${input.spaceTitle}`,
    body: `${input.senderName}: ${text}`,
  };
}

/** @deprecated Use formatPushNotification — kept for existing imports/tests. */
export const formatNtfyNotification = formatPushNotification;

export type BarkPublisherOptions = {
  baseUrl: string;
  deviceKey: string;
  maxRetries?: number;
  retryDelayMs?: number;
  requestTimeoutMs?: number;
  fetchImpl?: typeof fetch;
};

export class BarkPublisher {
  private readonly baseUrl: string;
  private readonly deviceKey: string;
  private readonly maxRetries: number;
  private readonly retryDelayMs: number;
  private readonly requestTimeoutMs: number;
  private readonly fetchImpl: typeof fetch;

  constructor(options: BarkPublisherOptions) {
    this.baseUrl = options.baseUrl.replace(/\/$/, "");
    this.deviceKey = options.deviceKey;
    this.maxRetries = options.maxRetries ?? 2;
    this.retryDelayMs = options.retryDelayMs ?? 250;
    this.requestTimeoutMs = options.requestTimeoutMs ?? 10_000;
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async publish(input: BarkPublishInput): Promise<void> {
    const url = `${this.baseUrl}/${encodeURIComponent(this.deviceKey)}`;
    let attempt = 0;
    let lastError: Error | undefined;
    const timeoutMs = input.timeoutMs ?? this.requestTimeoutMs;

    const payload: Record<string, unknown> = {
      title: input.title,
      body: input.body,
      group: input.group ?? "google-chat",
      sound: input.sound ?? "birdsong",
    };
    if (input.url) payload.url = input.url;
    if (input.badge !== undefined) payload.badge = input.badge;

    while (attempt <= this.maxRetries) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const response = await this.fetchImpl(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json; charset=utf-8",
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        if (response.ok) {
          return;
        }

        const detail = await response.text();
        lastError = new Error(
          `Bark publish failed (${response.status}): ${detail}`,
        );
      } catch (err) {
        lastError =
          err instanceof Error ? err : new Error("Bark publish failed");
      } finally {
        clearTimeout(timer);
      }

      attempt += 1;
      if (attempt <= this.maxRetries && this.retryDelayMs > 0) {
        await sleep(this.retryDelayMs);
      }
    }

    throw lastError ?? new Error("Bark publish failed");
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
