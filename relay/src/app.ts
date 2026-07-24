import type { RelayConfig } from "./config.js";
import { AccountStore } from "./accounts/store.js";
import { teardownAccount } from "./accounts/teardown.js";
import { handlePubSubPush } from "./handlers/pubsub.js";
import { NtfyPublisher } from "./ntfy/publisher.js";
import express from "express";

type AppDeps = {
  accountStore?: AccountStore;
  deleteSubscription?: (name: string) => Promise<void>;
  revokeToken?: (refreshToken: string) => Promise<void>;
};

export function createApp(config: RelayConfig, deps: AppDeps = {}) {
  const app = express();
  app.use(express.json());

  const publisher = new NtfyPublisher(config.ntfy);
  const store = deps.accountStore ?? new AccountStore();
  const deleteSubscription = deps.deleteSubscription ?? (async () => undefined);
  const revokeToken = deps.revokeToken ?? (async () => undefined);

  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  app.post("/test/notify", async (req, res) => {
    const { title, body } = req.body as { title?: string; body?: string };
    if (!title || !body) {
      res.status(400).json({ error: "title and body are required" });
      return;
    }

    await publisher.publish({ title, body, tags: ["test"] });
    res.json({ published: true });
  });

  app.post("/pubsub/push", async (req, res) => {
    await handlePubSubPush(req.body, {
      store,
      publish: (notification) => publisher.publish(notification),
      deepLinkScheme: config.deepLinkScheme,
    });
    res.status(204).send();
  });

  app.get("/accounts", (_req, res) => {
    res.json(store.list().map(({ refreshToken: _rt, ...account }) => account));
  });

  app.post("/accounts", (req, res) => {
    const { accountId, label, refreshToken, subscriptionName } = req.body as {
      accountId?: string;
      label?: string;
      refreshToken?: string;
      subscriptionName?: string;
    };

    if (!accountId || !label || !refreshToken) {
      res.status(400).json({ error: "accountId, label, and refreshToken are required" });
      return;
    }

    store.upsert({ accountId, label, refreshToken, subscriptionName });
    res.status(201).json({ accountId, label });
  });

  app.delete("/accounts/:accountId", async (req, res) => {
    await teardownAccount({
      store,
      accountId: decodeURIComponent(req.params.accountId),
      deleteSubscription,
      revokeToken,
    });
    res.status(204).send();
  });

  return app;
}

export function startServer(config: RelayConfig) {
  const app = createApp(config);
  return app.listen(config.port, () => {
    console.log(`relay listening on :${config.port}`);
  });
}

export { handlePubSubPush };
export type { RelayConfig } from "./config.js";
