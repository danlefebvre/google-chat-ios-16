export type NtfyPublishInput = {
  title: string;
  body: string;
  tags?: string[];
  clickUrl?: string;
  timeoutMs?: number;
};

export type FormatNotificationInput = {
  accountLabel: string;
  spaceTitle: string;
  senderName: string;
  messageText: string;
  maxBodyLength?: number;
};

export function formatNtfyNotification(input: FormatNotificationInput): {
  title: string;
  body: string;
} {
  const maxBodyLength = input.maxBodyLength ?? 200;
  const text =
    input.messageText.trim().length > 0
      ? input.messageText.trim()
      : "(attachment or empty message)";
  const prefix = `${input.senderName}: `;
  const available = Math.max(0, maxBodyLength - prefix.length);
  let bodyText = text;
  if (bodyText.length > available) {
    const cut = Math.max(0, available - 1);
    bodyText = `${bodyText.slice(0, cut)}…`;
  }

  return {
    title: `[${input.accountLabel}] ${input.spaceTitle}`,
    body: `${prefix}${bodyText}`,
  };
}

export type NtfyPublisherOptions = {
  baseUrl: string;
  topic: string;
  accessToken: string;
  maxRetries?: number;
  retryDelayMs?: number;
  requestTimeoutMs?: number;
  fetchImpl?: typeof fetch;
};

export class NtfyPublisher {
  private readonly baseUrl: string;
  private readonly topic: string;
  private readonly accessToken: string;
  private readonly maxRetries: number;
  private readonly retryDelayMs: number;
  private readonly requestTimeoutMs: number;
  private readonly fetchImpl: typeof fetch;

  constructor(options: NtfyPublisherOptions) {
    this.baseUrl = options.baseUrl.replace(/\/$/, "");
    this.topic = options.topic;
    this.accessToken = options.accessToken;
    this.maxRetries = options.maxRetries ?? 2;
    this.retryDelayMs = options.retryDelayMs ?? 250;
    this.requestTimeoutMs = options.requestTimeoutMs ?? 10_000;
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async publish(input: NtfyPublishInput): Promise<void> {
    const url = `${this.baseUrl}/${this.topic}`;
    let attempt = 0;
    let lastError: Error | undefined;
    const timeoutMs = input.timeoutMs ?? this.requestTimeoutMs;

    while (attempt <= this.maxRetries) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const response = await this.fetchImpl(url, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
            Title: encodeNtfyHeader(input.title),
            ...(input.tags?.length ? { Tags: input.tags.join(",") } : {}),
            ...(input.clickUrl ? { Click: input.clickUrl } : {}),
          },
          body: input.body,
          signal: controller.signal,
        });

        if (response.ok) {
          return;
        }

        const detail = await response.text();
        lastError = new Error(
          `ntfy publish failed (${response.status}): ${detail}`,
        );
      } catch (err) {
        lastError =
          err instanceof Error ? err : new Error("ntfy publish failed");
      } finally {
        clearTimeout(timer);
      }

      attempt += 1;
      if (attempt <= this.maxRetries && this.retryDelayMs > 0) {
        await sleep(this.retryDelayMs);
      }
    }

    throw lastError ?? new Error("ntfy publish failed");
  }
}

function encodeNtfyHeader(value: string): string {
  // ntfy accepts UTF-8 headers; keep simple ASCII-safe for tests/network layers.
  return value;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
