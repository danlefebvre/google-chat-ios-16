import { describe, it, expect, vi, beforeEach } from "vitest";
import { teardownAccount } from "../src/teardown.js";
import type { AccountStore, TeardownDeps } from "../src/teardown.js";

describe("teardownAccount", () => {
  let store: AccountStore;
  let deps: TeardownDeps;

  beforeEach(() => {
    store = {
      get: vi.fn().mockReturnValue({
        accountId: "issuer|sub-work",
        label: "Work",
        refreshToken: "rt",
        subscriptionName: "projects/p/subscriptions/work-events",
      }),
      delete: vi.fn(),
    };
    deps = {
      deleteWorkspaceSubscription: vi.fn().mockResolvedValue(undefined),
      revokeRefreshToken: vi.fn().mockResolvedValue(undefined),
      invalidateNtfyBinding: vi.fn().mockResolvedValue(undefined),
    };
  });

  it("runs teardown steps in order per PLAN", async () => {
    const steps: string[] = [];
    deps.deleteWorkspaceSubscription = vi.fn().mockImplementation(async () => {
      steps.push("delete_subscription");
    });
    deps.revokeRefreshToken = vi.fn().mockImplementation(async () => {
      steps.push("revoke_token");
    });
    deps.invalidateNtfyBinding = vi.fn().mockImplementation(async () => {
      steps.push("invalidate_ntfy");
    });
    store.delete = vi.fn().mockImplementation(() => {
      steps.push("delete_store");
    });

    await teardownAccount(store, deps, "issuer|sub-work");

    expect(steps).toEqual([
      "delete_subscription",
      "revoke_token",
      "invalidate_ntfy",
      "delete_store",
    ]);
  });

  it("throws when account not found", async () => {
    store.get = vi.fn().mockReturnValue(undefined);
    await expect(teardownAccount(store, deps, "missing")).rejects.toThrow(
      /not found/,
    );
  });
});
