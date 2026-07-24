import { describe, expect, it, vi } from "vitest";
import { teardownAccount } from "../src/accounts.js";
import type { AccountStore } from "../src/accounts.js";

describe("teardownAccount", () => {
  it("deletes subscription, revokes token, and removes account in order", async () => {
    const calls: string[] = [];
    const store: AccountStore = {
      get: vi.fn(),
      list: vi.fn(),
      save: vi.fn(),
      remove: vi.fn().mockImplementation(async () => {
        calls.push("remove");
      }),
    };

    const workspaceEvents = {
      deleteSubscription: vi.fn().mockImplementation(async () => {
        calls.push("deleteSubscription");
      }),
    };

    const oauth = {
      revokeRefreshToken: vi.fn().mockImplementation(async () => {
        calls.push("revokeRefreshToken");
      }),
    };

    await teardownAccount(
      { store, workspaceEvents, oauth },
      "issuer|sub-work",
      {
        id: "issuer|sub-work",
        label: "Work",
        refreshToken: "rt",
        subscriptionName: "subscriptions/work",
      },
    );

    expect(workspaceEvents.deleteSubscription).toHaveBeenCalledWith(
      "subscriptions/work",
    );
    expect(oauth.revokeRefreshToken).toHaveBeenCalledWith("rt");
    expect(store.remove).toHaveBeenCalledWith("issuer|sub-work");
    expect(calls).toEqual([
      "deleteSubscription",
      "revokeRefreshToken",
      "remove",
    ]);
  });
});
