import { describe, expect, it, vi } from "vitest";
import { AccountStore } from "../src/accounts/store.js";
import { teardownAccount } from "../src/accounts/teardown.js";

describe("teardownAccount", () => {
  it("deletes subscription, revokes token, and removes account binding", async () => {
    const store = new AccountStore();
    store.upsert({
      accountId: "issuer|sub",
      label: "Work",
      refreshToken: "rt",
      subscriptionName: "subscriptions/123",
    });

    const deleteSubscription = vi.fn().mockResolvedValue(undefined);
    const revokeToken = vi.fn().mockResolvedValue(undefined);

    await teardownAccount({
      store,
      accountId: "issuer|sub",
      deleteSubscription,
      revokeToken,
    });

    expect(deleteSubscription).toHaveBeenCalledWith("subscriptions/123");
    expect(revokeToken).toHaveBeenCalledWith("rt");
    expect(store.get("issuer|sub")).toBeUndefined();
  });
});
