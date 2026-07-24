import { parseChatEvent } from "./events.js";
import type { BuildNtfyPayloadInput } from "./ntfy.js";

export interface PubSubEnvelope {
  message: {
    data: string;
    attributes?: Record<string, string>;
  };
}

export interface RelayServices {
  getAccountBySubscription: (subscriptionName: string) => {
    id: string;
    label: string;
  } | null;
  shouldDeliver: (context: {
    accountId: string;
    spaceResourceName: string;
    at: Date;
  }) => boolean;
  publishNotification: (
    input: BuildNtfyPayloadInput & { spaceResourceName?: string },
  ) => Promise<void>;
}

export async function handlePubSubPush(
  services: RelayServices,
  envelope: PubSubEnvelope,
): Promise<void> {
  const subscriptionName =
    envelope.message.attributes?.googclientplussubscription;
  if (!subscriptionName) {
    return;
  }

  const account = services.getAccountBySubscription(subscriptionName);
  if (!account) {
    return;
  }

  const decoded = Buffer.from(envelope.message.data, "base64").toString(
    "utf8",
  );
  const workspaceEvent = JSON.parse(decoded) as Parameters<
    typeof parseChatEvent
  >[0];
  const chatEvent = parseChatEvent(workspaceEvent);
  if (!chatEvent) {
    return;
  }

  const shouldDeliver = services.shouldDeliver({
    accountId: account.id,
    spaceResourceName: chatEvent.spaceResourceName,
    at: new Date(),
  });

  if (!shouldDeliver) {
    return;
  }

  await services.publishNotification({
    accountLabel: account.label,
    spaceTitle: chatEvent.spaceTitle,
    senderName: chatEvent.senderName,
    messagePreview: chatEvent.messagePreview,
    spaceResourceName: chatEvent.spaceResourceName,
  });
}
