import type { ParsedChatEvent, QuietHours } from "./types.js";

export type RawChatEventInput = {
  accountId: string;
  accountLabel: string;
  ceType: string;
  data: unknown;
};

type MessagePayload = {
  message?: {
    name?: string;
    text?: string;
    createTime?: string;
    space?: { name?: string; displayName?: string };
    sender?: { displayName?: string; name?: string };
  };
};

export function parseChatEvent(
  input: RawChatEventInput,
): ParsedChatEvent | null {
  if (!input.ceType.includes("chat.message") || !input.ceType.includes("created")) {
    return null;
  }

  const data = (input.data ?? {}) as MessagePayload;
  const message = data.message;
  if (!message?.name || !message.space?.name) {
    return null;
  }

  return {
    accountId: input.accountId,
    accountLabel: input.accountLabel,
    spaceName: message.space.name,
    spaceTitle: message.space.displayName?.trim() || message.space.name,
    messageName: message.name,
    senderName: message.sender?.displayName?.trim() || "Someone",
    messageText: message.text ?? "",
    createTime: message.createTime ?? new Date().toISOString(),
    eventType: "message.created",
  };
}

export type NotifyDecision =
  | { notify: true }
  | { notify: false; reason: "account_muted" | "space_muted" | "quiet_hours" };

export type NotifyContext = {
  mutedAccountIds: Set<string>;
  mutedSpaceKeys: Set<string>;
  quietHours: QuietHours | null;
  now: Date;
};

export function shouldNotify(
  event: ParsedChatEvent,
  ctx: NotifyContext,
): NotifyDecision {
  if (ctx.mutedAccountIds.has(event.accountId)) {
    return { notify: false, reason: "account_muted" };
  }

  const spaceKey = `${event.accountId}:${event.spaceName}`;
  if (ctx.mutedSpaceKeys.has(spaceKey)) {
    return { notify: false, reason: "space_muted" };
  }

  if (ctx.quietHours && isInQuietHours(ctx.now, ctx.quietHours)) {
    return { notify: false, reason: "quiet_hours" };
  }

  return { notify: true };
}

export function isInQuietHours(now: Date, quiet: QuietHours): boolean {
  const hour = hourInTimeZone(now, quiet.timeZone);
  const { startHour, endHour } = quiet;

  if (startHour === endHour) {
    return false;
  }

  // Window that wraps midnight, e.g. 22 → 7
  if (startHour > endHour) {
    return hour >= startHour || hour < endHour;
  }

  return hour >= startHour && hour < endHour;
}

function hourInTimeZone(date: Date, timeZone: string): number {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      hour: "numeric",
      hourCycle: "h23",
      timeZone,
    }).formatToParts(date);
    const hour = parts.find((p) => p.type === "hour")?.value;
    return hour ? Number(hour) : date.getUTCHours();
  } catch {
    return date.getUTCHours();
  }
}
