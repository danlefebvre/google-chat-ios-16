import type { NtfyConfig, NotificationPayload } from "./types.js";

/** Bound outbound ntfy latency so a stalled endpoint cannot hang request handlers. */
export const NTFY_TIMEOUT_MS = 10_000;

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

  let response: Response;
  try {
    response = await fetch(url, {
      method: "POST",
      headers,
      body: notification.body,
      signal: AbortSignal.timeout(NTFY_TIMEOUT_MS),
    });
  } catch (err) {
    if (err instanceof Error && (err.name === "TimeoutError" || err.name === "AbortError")) {
      throw new Error(`ntfy publish timed out after ${NTFY_TIMEOUT_MS}ms`);
    }
    throw err;
  }

  if (!response.ok) {
    throw new Error(`ntfy publish failed: ${response.status} ${response.statusText}`);
  }
}
