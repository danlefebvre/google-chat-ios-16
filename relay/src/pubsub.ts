import { parseChatEvent, shouldNotify } from "./events.js";
import { formatNtfyNotification, type NtfyPublisher } from "./ntfy.js";
import type { AccountStore } from "./store.js";

export type PubSubPushBody = {
  message?: {
    data?: string;
    attributes?: Record<string, string>;
    messageId?: string;
  };
};

export async function handlePubSubPush(deps: {
  body: PubSubPushBody;
  store: AccountStore;
  publisher: NtfyPublisher;
  deepLinkScheme?: string;
  now?: Date;
}): Promise<{ status: number; skipped?: string }> {
  const message = deps.body.message;
  if (!message?.data) {
    return { status: 400 };
  }

  let data: unknown;
  try {
    data = JSON.parse(Buffer.from(message.data, "base64").toString("utf8"));
  } catch {
    return { status: 400 };
  }

  const attributes = message.attributes ?? {};
  const accountId = attributes.accountId ?? attributes.account_id;
  if (!accountId) {
    return { status: 204, skipped: "missing_account_id" };
  }

  const account = deps.store.getAccount(accountId);
  if (!account || !account.ntfyBindingActive) {
    return { status: 204, skipped: "unknown_or_inactive_account" };
  }

  const ceType =
    attributes["ce-type"] ??
    attributes.ceType ??
    attributes.eventType ??
    "";

  const parsed = parseChatEvent({
    accountId,
    accountLabel: account.label,
    ceType,
    data,
  });

  if (!parsed) {
    return { status: 204, skipped: "unsupported_event" };
  }

  const mutedSpaceKeys = new Set(
    account.mutedSpaces.map((space) => `${account.accountId}:${space}`),
  );
  const mutedAccountIds = new Set(
    account.muted ? [account.accountId] : [],
  );

  const decision = shouldNotify(parsed, {
    mutedAccountIds,
    mutedSpaceKeys,
    quietHours: deps.store.getQuietHours(),
    now: deps.now ?? new Date(),
  });

  if (!decision.notify) {
    return { status: 204, skipped: decision.reason };
  }

  const formatted = formatNtfyNotification({
    accountLabel: parsed.accountLabel,
    spaceTitle: parsed.spaceTitle,
    senderName: parsed.senderName,
    messageText: parsed.messageText,
  });

  const clickUrl = deps.deepLinkScheme
    ? `${deps.deepLinkScheme}://space/${encodeURIComponent(parsed.spaceName)}?accountId=${encodeURIComponent(parsed.accountId)}`
    : undefined;

  await deps.publisher.publish({
    title: formatted.title,
    body: formatted.body,
    tags: ["speech_balloon"],
    clickUrl,
  });

  return { status: 204 };
}
