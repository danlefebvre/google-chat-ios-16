export type NtfyNotificationInput = {
  accountLabel: string;
  spaceTitle: string;
  senderName: string;
  messageText: string;
  spaceResourceName?: string;
  deepLinkScheme?: string;
  maxBodyLength?: number;
};

export type FormattedNtfyNotification = {
  title: string;
  body: string;
  click?: string;
  tags?: string[];
};

export function formatNtfyNotification(input: NtfyNotificationInput): FormattedNtfyNotification {
  const title = `[${input.accountLabel}] ${input.spaceTitle}`;
  const prefix = `${input.senderName}: `;
  const maxLen = input.maxBodyLength ?? 200;
  let text = input.messageText.trim();

  if (prefix.length + text.length > maxLen) {
    const allowed = Math.max(0, maxLen - prefix.length - 1);
    text = `${text.slice(0, allowed)}…`;
  }

  const body = `${prefix}${text}`;
  const result: FormattedNtfyNotification = {
    title,
    body,
    tags: ["google-chat", input.accountLabel.toLowerCase()],
  };

  if (input.spaceResourceName && input.deepLinkScheme) {
    result.click = `${input.deepLinkScheme}://space/${encodeURIComponent(input.spaceResourceName)}`;
  }

  return result;
}
