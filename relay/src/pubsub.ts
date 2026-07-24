import type { ChatMessageEvent } from "./types.js";

interface PubSubPushBody {
  message?: {
    data?: string;
    messageId?: string;
    publishTime?: string;
  };
  subscription?: string;
}

export function parsePubSubPush(body: PubSubPushBody): unknown {
  const data = body.message?.data;
  if (!data) {
    throw new Error("Pub/Sub push missing message.data");
  }
  const json = Buffer.from(data, "base64").toString("utf8");
  return JSON.parse(json);
}

interface WorkspaceEventEnvelope {
  payload?: {
    message?: {
      name?: string;
      text?: string;
      sender?: { name?: string; displayName?: string };
      space?: { name?: string; displayName?: string };
      createTime?: string;
    };
    space?: unknown;
  };
}

export function extractChatMessageEvent(
  envelope: WorkspaceEventEnvelope,
): ChatMessageEvent | null {
  const message = envelope.payload?.message;
  if (!message?.space?.name || !message.text) {
    return null;
  }

  return {
    spaceName: message.space.name,
    spaceTitle: message.space.displayName ?? message.space.name,
    senderName: message.sender?.displayName ?? "Someone",
    messageText: message.text,
    messageName: message.name ?? "",
    createTime: message.createTime ?? new Date().toISOString(),
  };
}
