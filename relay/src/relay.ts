import { formatNotification } from "./ntfy.js";
import { isMuted, isQuietHours } from "./mute.js";
import { extractChatMessageEvent } from "./pubsub.js";
import type { HandleResult, RelayDeps } from "./types.js";

export async function handleChatEvent(
  deps: RelayDeps,
  accountId: string,
  envelope: unknown,
): Promise<HandleResult> {
  const account = deps.accounts.get(accountId);
  if (!account) {
    return { published: false, reason: "unknown_account" };
  }

  const event = extractChatMessageEvent(
    envelope as Parameters<typeof extractChatMessageEvent>[0],
  );
  if (!event) {
    return { published: false, reason: "not_a_message" };
  }

  if (isMuted(deps.mutes, accountId, event.spaceName)) {
    const spaceKey = `${accountId}:${event.spaceName}`;
    if (deps.mutes.accounts.has(accountId)) {
      return { published: false, reason: "muted_account" };
    }
    if (deps.mutes.spaces.has(spaceKey)) {
      return { published: false, reason: "muted_space" };
    }
  }

  const now = deps.now?.() ?? new Date();
  if (isQuietHours(deps.quietHours, now)) {
    return { published: false, reason: "quiet_hours" };
  }

  const { title, body } = formatNotification({
    accountLabel: account.label,
    spaceTitle: event.spaceTitle,
    sender: event.senderName,
    messageText: event.messageText,
  });

  const tagLabel = account.label.toLowerCase().replace(/\s+/g, "-");

  await deps.publish({
    title,
    body,
    tags: ["chat", tagLabel],
    click: `googlechatmulti://space/${encodeURIComponent(accountId)}/${encodeURIComponent(event.spaceName)}`,
  });

  return { published: true, reason: "ok" };
}
