export interface NtfyPayload {
  title: string;
  message: string;
  click?: string;
  tags?: string[];
}

export interface BuildNtfyPayloadInput {
  accountLabel: string;
  spaceTitle: string;
  senderName: string;
  messagePreview: string;
  spaceResourceName?: string;
  deepLinkScheme?: string;
  maxPreviewLength?: number;
}

export function buildNtfyPayload(input: BuildNtfyPayloadInput): NtfyPayload {
  const maxLen = input.maxPreviewLength ?? 200;
  const preview =
    input.messagePreview.length > maxLen
      ? input.messagePreview.slice(0, maxLen)
      : input.messagePreview;

  const payload: NtfyPayload = {
    title: `[${input.accountLabel}] ${input.spaceTitle}`,
    message: `${input.senderName}: ${preview}`,
  };

  if (input.spaceResourceName && input.deepLinkScheme) {
    payload.click = `${input.deepLinkScheme}://space/${encodeURIComponent(input.spaceResourceName)}`;
  }

  return payload;
}

export async function publishToNtfy(
  config: { baseUrl: string; topic: string; accessToken?: string },
  payload: NtfyPayload,
): Promise<void> {
  const url = `${config.baseUrl.replace(/\/$/, "")}/${config.topic}`;
  const headers: Record<string, string> = {
    Title: payload.title,
  };

  if (config.accessToken) {
    headers.Authorization = `Bearer ${config.accessToken}`;
  }

  if (payload.click) {
    headers.Click = payload.click;
  }

  if (payload.tags?.length) {
    headers.Tags = payload.tags.join(",");
  }

  const response = await fetch(url, {
    method: "POST",
    headers,
    body: payload.message,
  });

  if (!response.ok) {
    throw new Error(`ntfy publish failed: ${response.status}`);
  }
}
