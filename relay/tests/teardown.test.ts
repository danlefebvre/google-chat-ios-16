import { describe, it, expect, vi } from "vitest";
import { teardownAccount } from "../src/teardown.js";

describe("teardownAccount", () => {
  it("deletes subscription, revokes token, and removes from store", async () => {
    const deleteSubscription = vi.fn().mockResolvedValue(undefined);
    const revokeToken = vi.fn().mockResolvedValue(undefined);
    const storeRemove = vi.fn().mockResolvedValue(undefined);

    await teardownAccount(
      {
        accountId: "issuer|sub1",
        label: "Work",
        refreshToken: "rt1",
        subscriptionName: "projects/p/subscriptions/s1",
        mutedSpaces: [],
        muted: false,
      },
      { deleteSubscription, revokeToken, storeRemove },
    );

    expect(deleteSubscription).toHaveBeenCalledWith("projects/p/subscriptions/s1");
    expect(revokeToken).toHaveBeenCalledWith("rt1");
    expect(storeRemove).toHaveBeenCalledWith("issuer|sub1");
  });

  it("continues credential cleanup when subscription deletion fails", async () => {
    const deleteSubscription = vi.fn().mockRejectedValue(new Error("gone"));
    const revokeToken = vi.fn().mockResolvedValue(undefined);
    const storeRemove = vi.fn().mockResolvedValue(undefined);

    await expect(
      teardownAccount(
        {
          accountId: "issuer|sub1",
          label: "Work",
          refreshToken: "rt1",
          subscriptionName: "projects/p/subscriptions/s1",
          mutedSpaces: [],
          muted: false,
        },
        { deleteSubscription, revokeToken, storeRemove },
      ),
    ).rejects.toThrow(AggregateError);

    expect(revokeToken).toHaveBeenCalledWith("rt1");
    expect(storeRemove).toHaveBeenCalledWith("issuer|sub1");
  });
});
