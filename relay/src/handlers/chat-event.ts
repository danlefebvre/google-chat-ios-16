export type ParsedChatEvent = {
  type: "message.created";
  spaceResourceName: string;
  spaceTitle: string;
  senderName: string;
  messageText: string;
};

type RawChatEvent = {
  type?: string;
  chatMessage?: {
    text?: string;
    sender?: { displayName?: string };
    space?: { name?: string; displayName?: string };
  };
};

export function parseChatEvent(raw: RawChatEvent): ParsedChatEvent | null {
  if (raw.type !== "google.workspace.chat.message.v1.created") {
    return null;
  }

  const message = raw.chatMessage;
  if (!message?.space?.name) {
    return null;
  }

  return {
    type: "message.created",
    spaceResourceName: message.space.name,
    spaceTitle: message.space.displayName ?? message.space.name,
    senderName: message.sender?.displayName ?? "Someone",
    messageText: message.text ?? "",
  };
}
