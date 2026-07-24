export interface ChatMessageEvent {
  type: "message.created";
  spaceResourceName: string;
  spaceTitle: string;
  senderName: string;
  messagePreview: string;
}

interface WorkspaceEventEnvelope {
  type: string;
  data: {
    message?: {
      name?: string;
      text?: string;
      sender?: { displayName?: string };
      space?: { name?: string; displayName?: string };
      attachment?: Array<{ name?: string }>;
    };
  };
}

export function parseChatEvent(
  envelope: WorkspaceEventEnvelope,
): ChatMessageEvent | null {
  if (envelope.type !== "google.workspace.chat.message.v1.created") {
    return null;
  }

  const message = envelope.data.message;
  if (!message?.space?.name) {
    return null;
  }

  let preview = message.text?.trim() ?? "";
  if (!preview && message.attachment?.length) {
    preview = "[attachment]";
  }

  return {
    type: "message.created",
    spaceResourceName: message.space.name,
    spaceTitle: message.space.displayName ?? message.space.name,
    senderName: message.sender?.displayName ?? "Someone",
    messagePreview: preview,
  };
}
