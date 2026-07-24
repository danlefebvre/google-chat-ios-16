import { describe, it, expect, vi, beforeEach } from "vitest";
import { handleChatEvent } from "../src/relay.js";
import type { AccountBinding, RelayDeps } from "../src/types.js";

const account: AccountBinding = {
  accountId: "https://accounts.google.com|sub-work",
  label: "Work",
  refreshToken: "rt-work",
  subscriptionName: "projects/p/subscriptions/work-sub",
};

function makeDeps(overrides: Partial<RelayDeps> = {}): RelayDeps {
  return {
    publish: vi.fn().mockResolvedValue(undefined),
    mutes: { accounts: new Set(), spaces: new Set() },
    quietHours: null,
    accounts: new Map([[account.accountId, account]]),
    ...overrides,
  };
}

describe("handleChatEvent", () => {
  beforeEach(() => vi.restoreAllMocks());

  it("publishes ntfy notification for a chat message", async () => {
    const deps = makeDeps();
    const envelope = {
      payload: {
        message: {
          name: "spaces/AAA/messages/BBB",
          text: "deploy looks good",
          sender: { displayName: "Alice" },
          space: { name: "spaces/AAA", displayName: "#eng-standup" },
          createTime: "2026-07-24T12:00:00Z",
        },
      },
    };

    const result = await handleChatEvent(deps, account.accountId, envelope);
    expect(result).toEqual({ published: true, reason: "ok" });
    expect(deps.publish).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "[Work] #eng-standup",
        body: "Alice: deploy looks good",
        tags: ["chat", "work"],
      }),
    );
  });

  it("skips muted account", async () => {
    const deps = makeDeps({
      mutes: { accounts: new Set([account.accountId]), spaces: new Set() },
    });
    const envelope = {
      payload: {
        message: {
          text: "hi",
          sender: { displayName: "Bob" },
          space: { name: "spaces/X", displayName: "DM" },
        },
      },
    };
    const result = await handleChatEvent(deps, account.accountId, envelope);
    expect(result).toEqual({ published: false, reason: "muted_account" });
    expect(deps.publish).not.toHaveBeenCalled();
  });

  it("skips muted space", async () => {
    const deps = makeDeps({
      mutes: {
        accounts: new Set(),
        spaces: new Set([`${account.accountId}:spaces/AAA`]),
      },
    });
    const envelope = {
      payload: {
        message: {
          text: "hi",
          sender: { displayName: "Bob" },
          space: { name: "spaces/AAA", displayName: "DM" },
        },
      },
    };
    const result = await handleChatEvent(deps, account.accountId, envelope);
    expect(result).toEqual({ published: false, reason: "muted_space" });
  });

  it("skips during quiet hours", async () => {
    const deps = makeDeps({
      quietHours: { startHour: 0, endHour: 24, timezone: "UTC" },
    });
    const envelope = {
      payload: {
        message: {
          text: "hi",
          sender: { displayName: "Bob" },
          space: { name: "spaces/X", displayName: "DM" },
        },
      },
    };
    const result = await handleChatEvent(deps, account.accountId, envelope);
    expect(result).toEqual({ published: false, reason: "quiet_hours" });
  });

  it("returns ignored for non-message events", async () => {
    const deps = makeDeps();
    const result = await handleChatEvent(deps, account.accountId, {
      payload: { space: {} },
    });
    expect(result).toEqual({ published: false, reason: "not_a_message" });
  });
});
