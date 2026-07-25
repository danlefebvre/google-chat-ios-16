import { parseChatEvent, shouldNotify } from "./events.js";
import { formatNtfyNotification, type NtfyPublisher } from "./ntfy.js";
import type { AccountStore } from "./store.js";
import { normalizeSubscriptionName } from "./store.js";

export type PubSubPushBody = {
  message?: {
    data?: string;
    attributes?: Record<string, string>;
    messageId?: string;
    orderingKey?: string;
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
  // Real Workspace Events messages identify the subscription via ce-source /
  // orderingKey — they do NOT include our local accountId attribute.
  const subscriptionHint =
    attributes["ce-source"] ??
    attributes.ceSource ??
    message.orderingKey ??
    attributes.accountId ??
    attributes.account_id ??
    "";

  const account = resolveAccount(deps.store, subscriptionHint);
  if (!account || !account.ntfyBindingActive) {
    console.warn("pubsub skip: unknown subscription", subscriptionHint);
    return { status: 204, skipped: "unknown_or_inactive_account" };
  }

  const ceType =
    attributes["ce-type"] ??
    attributes.ceType ??
    attributes.eventType ??
    "";

  const parsed = parseChatEvent({
    accountId: account.accountId,
    accountLabel: account.label,
    ceType,
    data,
  });

  if (!parsed) {
    console.warn("pubsub skip: unsupported event", ceType);
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

function resolveAccount(store: AccountStore, hint: string) {
  if (!hint) {
    return undefined;
  }
  // Prefer explicit accountId (tests / legacy) before subscription lookup.
  const byId = store.getAccount(hint);
  if (byId) {
    return byId;
  }
  return store.getAccountBySubscription(normalizeSubscriptionName(hint));
}
