import type { NtfyConfig, NotificationPayload } from "./types.js";

export async function publishToNtfy(
  config: NtfyConfig,
  notification: NotificationPayload,
): Promise<void> {
  const url = `${config.baseUrl.replace(/\/$/, "")}/${config.topic}`;
  const headers: Record<string, string> = {
    Title: notification.title,
    "Content-Type": "text/plain; charset=utf-8",
  };

  if (config.accessToken) {
    headers.Authorization = `Bearer ${config.accessToken}`;
  }

  const response = await fetch(url, {
    method: "POST",
    headers,
    body: notification.body,
  });

  if (!response.ok) {
    throw new Error(`ntfy publish failed: ${response.status} ${response.statusText}`);
  }
}
