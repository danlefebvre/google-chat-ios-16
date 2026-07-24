import { describe, it, expect } from "vitest";
import { InMemoryAccountStore } from "../src/store.js";

describe("InMemoryAccountStore", () => {
  it("adds and retrieves accounts by id", async () => {
    const store = new InMemoryAccountStore();
    await store.upsert({
      accountId: "issuer|sub1",
      label: "Work",
      refreshToken: "rt1",
      subscriptionName: "projects/p/subscriptions/s1",
      mutedSpaces: [],
      muted: false,
    });

    const account = await store.get("issuer|sub1");
    expect(account?.label).toBe("Work");
  });

  it("lists all accounts", async () => {
    const store = new InMemoryAccountStore();
    await store.upsert({
      accountId: "issuer|sub1",
      label: "Work",
      refreshToken: "rt1",
      subscriptionName: "s1",
      mutedSpaces: [],
      muted: false,
    });
    await store.upsert({
      accountId: "issuer|sub2",
      label: "Personal",
      refreshToken: "rt2",
      subscriptionName: "s2",
      mutedSpaces: [],
      muted: false,
    });

    expect(await store.list()).toHaveLength(2);
  });

  it("removes account on teardown", async () => {
    const store = new InMemoryAccountStore();
    await store.upsert({
      accountId: "issuer|sub1",
      label: "Work",
      refreshToken: "rt1",
      subscriptionName: "s1",
      mutedSpaces: [],
      muted: false,
    });

    await store.remove("issuer|sub1");
    expect(await store.get("issuer|sub1")).toBeUndefined();
  });
});
