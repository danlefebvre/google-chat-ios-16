import type { NtfyConfig, NtfyNotification } from "./types.js";

const DEFAULT_MAX_BODY = 200;

export function truncatePreview(text: string, maxLength: number): string {
  if (text.length <= maxLength) {
    return text;
  }
  return text.slice(0, maxLength - 1) + "…";
}

export function formatNotification(input: {
  accountLabel: string;
  spaceTitle: string;
  sender: string;
  messageText: string;
  maxBodyLength?: number;
}): { title: string; body: string } {
  const maxLen = input.maxBodyLength ?? DEFAULT_MAX_BODY;
  const preview = truncatePreview(
    input.messageText,
    maxLen - `${input.sender}: `.length,
  );
  return {
    title: `[${input.accountLabel}] ${input.spaceTitle}`,
    body: `${input.sender}: ${preview}`,
  };
}

export function buildNtfyUrl(config: NtfyConfig): string {
  return `${config.server}/${config.topic}`;
}

export async function publishToNtfy(
  config: NtfyConfig,
  notification: NtfyNotification,
): Promise<void> {
  const headers: Record<string, string> = {
    Title: notification.title,
  };

  if (notification.tags?.length) {
    headers.Tags = notification.tags.join(",");
  }
  if (notification.click) {
    headers.Click = notification.click;
  }
  if (notification.priority !== undefined) {
    headers.Priority = String(notification.priority);
  }
  if (config.accessToken) {
    headers.Authorization = `Bearer ${config.accessToken}`;
  }

  const response = await fetch(buildNtfyUrl(config), {
    method: "POST",
    headers,
    body: notification.body,
  });

  if (!response.ok) {
    throw new Error(
      `ntfy publish failed: ${response.status} ${response.statusText}`,
    );
  }
}
