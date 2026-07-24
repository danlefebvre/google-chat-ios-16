import type { FormattedNtfyNotification } from "./format.js";

export type NtfyConfig = {
  baseUrl: string;
  topic: string;
  accessToken?: string;
};

type FetchFn = typeof fetch;

export class NtfyPublisher {
  constructor(
    private readonly config: NtfyConfig,
    private readonly fetchImpl: FetchFn = fetch,
    private readonly maxAttempts = 3,
  ) {}

  async publish(notification: FormattedNtfyNotification): Promise<void> {
    const url = `${this.config.baseUrl}/${this.config.topic}`;
    const headers: Record<string, string> = {
      Title: notification.title,
      Tags: (notification.tags ?? []).join(","),
    };

    if (notification.click) {
      headers.Click = notification.click;
    }

    if (this.config.accessToken) {
      headers.Authorization = `Bearer ${this.config.accessToken}`;
    }

    let lastError: Error | undefined;

    for (let attempt = 1; attempt <= this.maxAttempts; attempt++) {
      const response = await this.fetchImpl(url, {
        method: "POST",
        headers,
        body: notification.body,
      });

      if (response.ok) {
        return;
      }

      lastError = new Error(`ntfy publish failed with status ${response.status}`);
      if (response.status < 500) {
        throw lastError;
      }
    }

    throw lastError ?? new Error("ntfy publish failed");
  }
}
