import type { FormatNotificationInput, NotificationPayload } from "./types.js";

const MAX_BODY_LENGTH = 200;

export function formatNotification(input: FormatNotificationInput): NotificationPayload {
  const title = `[${input.accountLabel}] ${input.spaceTitle}`;
  let body = input.messageText
    ? `${input.senderName}: ${input.messageText}`
    : `${input.senderName}:`;

  if (body.length > MAX_BODY_LENGTH) {
    body = body.slice(0, MAX_BODY_LENGTH - 1) + "…";
  }

  return { title, body };
}
