import type { RelayAccount, MuteConfig, NotificationPayload } from "./types.js";
import { formatNotification } from "./format-notification.js";
import { shouldNotify } from "./mutes.js";

interface PubSubEnvelope {
  message?: {
    data?: string;
    attributes?: Record<string, string>;
  };
}

/** Workspace Events Chat message payload (CloudEvents data field). */
interface ChatMessageEvent {
  message?: {
    name?: string;
    text?: string;
    sender?: { displayName?: string; name?: string };
    space?: { displayName?: string; name?: string };
  };
}

interface HandlePubSubOptions {
  publish: (notification: NotificationPayload) => Promise<void>;
  muteConfig: MuteConfig;
  now: Date;
}

const MESSAGE_CREATED = "google.workspace.chat.message.v1.created";

export async function handlePubSubMessage(
  envelope: PubSubEnvelope,
  account: RelayAccount,
  options: HandlePubSubOptions,
): Promise<void> {
  if (!envelope.message?.data) {
    return;
  }

  const eventType = envelope.message.attributes?.["ce-type"];
  if (eventType !== MESSAGE_CREATED) {
    return;
  }

  const decoded = Buffer.from(envelope.message.data, "base64").toString("utf-8");
  let event: ChatMessageEvent;
  try {
    event = JSON.parse(decoded) as ChatMessageEvent;
  } catch {
    return;
  }

  const message = event.message;
  if (!message) {
    return;
  }

  const spaceName = message.space?.name ?? "";
  const muteConfig: MuteConfig = {
    ...options.muteConfig,
    mutedAccounts: account.muted
      ? [...options.muteConfig.mutedAccounts, account.accountId]
      : options.muteConfig.mutedAccounts,
    mutedSpaces: [
      ...options.muteConfig.mutedSpaces,
      ...account.mutedSpaces.map((s) => `${account.accountId}:${s}`),
    ],
  };

  if (
    !shouldNotify(
      { accountId: account.accountId, spaceName, now: options.now },
      muteConfig,
    )
  ) {
    return;
  }

  const notification = formatNotification({
    accountLabel: account.label,
    spaceTitle: message.space?.displayName ?? spaceName,
    senderName: message.sender?.displayName ?? "Unknown",
    messageText: message.text ?? "",
  });

  await options.publish(notification);
}
