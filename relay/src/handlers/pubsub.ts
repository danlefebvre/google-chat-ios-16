import type { AccountStore } from "../accounts/store.js";
import { formatNtfyNotification } from "../ntfy/format.js";
import { parseChatEvent } from "./chat-event.js";
import { shouldNotify } from "../mutes/policy.js";
import type { FormattedNtfyNotification } from "../ntfy/format.js";

type PubSubEnvelope = {
  message?: {
    data?: string;
  };
};

type PushPayload = {
  accountId: string;
  event: unknown;
};

type HandlerDeps = {
  store: AccountStore;
  publish: (notification: FormattedNtfyNotification) => Promise<void>;
  deepLinkScheme: string;
  now?: Date;
};

export async function handlePubSubPush(envelope: PubSubEnvelope, deps: HandlerDeps): Promise<void> {
  const data = envelope.message?.data;
  if (!data) {
    return;
  }

  const payload = JSON.parse(Buffer.from(data, "base64").toString("utf8")) as PushPayload;
  const account = deps.store.get(payload.accountId);
  if (!account) {
    return;
  }

  const parsed = parseChatEvent(payload.event as Parameters<typeof parseChatEvent>[0]);
  if (!parsed) {
    return;
  }

  const mutedSpaces = new Set(
    (account.mutedSpaces ?? []).map((space) => `${account.accountId}:${space}`),
  );

  if (
    !shouldNotify({
      accountId: account.accountId,
      spaceResourceName: parsed.spaceResourceName,
      mutedAccounts: account.muted ? new Set([account.accountId]) : new Set(),
      mutedSpaces,
      quietHours: account.quietHours ?? null,
      now: deps.now ?? new Date(),
    })
  ) {
    return;
  }

  const notification = formatNtfyNotification({
    accountLabel: account.label,
    spaceTitle: parsed.spaceTitle,
    senderName: parsed.senderName,
    messageText: parsed.messageText,
    spaceResourceName: parsed.spaceResourceName,
    deepLinkScheme: deps.deepLinkScheme,
  });

  await deps.publish(notification);
}
