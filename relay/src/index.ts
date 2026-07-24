import express from "express";
import type { Server } from "node:http";
import { appConfig } from "./config.js";
import { healthResponse } from "./health.js";
import { publishToNtfy } from "./ntfy.js";
import { parsePubSubPush } from "./pubsub.js";
import { handleChatEvent } from "./relay.js";
import { teardownAccount } from "./teardown.js";
import { InMemoryAccountStore, loadMutesFromEnv } from "./store.js";
import type { RelayDeps } from "./types.js";

export interface AppContext {
  config: ReturnType<typeof appConfig>;
  store: InMemoryAccountStore;
  deps: RelayDeps;
}

export function createApp(ctx?: Partial<AppContext>): express.Application {
  const config = ctx?.config ?? appConfig();
  const store = ctx?.store ?? new InMemoryAccountStore();
  const mutes = loadMutesFromEnv();

  const deps: RelayDeps = ctx?.deps ?? {
    publish: (notification) => publishToNtfy(config.ntfy, notification),
    mutes,
    quietHours: config.quietHours ?? null,
    accounts: new Map(store.list().map((a) => [a.accountId, a])),
  };

  // Keep accounts map in sync with store mutations
  const syncAccounts = () => {
    deps.accounts = new Map(store.list().map((a) => [a.accountId, a]));
  };

  const app = express();
  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.json(healthResponse(config.version));
  });

  /** Manual ntfy publish for Phase 0 smoke tests */
  app.post("/test/notify", async (req, res) => {
    try {
      const { title, body, tags } = req.body as {
        title?: string;
        body?: string;
        tags?: string[];
      };
      if (!title || !body) {
        res.status(400).json({ error: "title and body required" });
        return;
      }
      await deps.publish({ title, body, tags });
      res.json({ ok: true });
    } catch (err) {
      res.status(502).json({
        error: err instanceof Error ? err.message : "publish failed",
      });
    }
  });

  /** Pub/Sub push receiver */
  app.post("/pubsub/push", async (req, res) => {
    try {
      const accountId = req.header("X-Account-Id");
      if (!accountId) {
        res.status(400).json({ error: "X-Account-Id header required" });
        return;
      }
      syncAccounts();
      const envelope = parsePubSubPush(req.body);
      const result = await handleChatEvent(deps, accountId, envelope);
      res.json(result);
    } catch (err) {
      res.status(400).json({
        error: err instanceof Error ? err.message : "invalid push",
      });
    }
  });

  app.post("/accounts", (req, res) => {
    const account = req.body;
    if (!account?.accountId || !account?.label || !account?.refreshToken) {
      res.status(400).json({ error: "accountId, label, refreshToken required" });
      return;
    }
    store.set({
      accountId: account.accountId,
      label: account.label,
      refreshToken: account.refreshToken,
      subscriptionName:
        account.subscriptionName ??
        `projects/${config.google.projectId ?? "local"}/subscriptions/${account.accountId}`,
    });
    syncAccounts();
    res.status(201).json({ ok: true });
  });

  app.delete("/accounts/:accountId", async (req, res) => {
    try {
      syncAccounts();
      await teardownAccount(store, {
        deleteWorkspaceSubscription: async () => {},
        revokeRefreshToken: async () => {},
        invalidateNtfyBinding: async () => {},
      }, req.params.accountId);
      syncAccounts();
      res.json({ ok: true });
    } catch (err) {
      res.status(404).json({
        error: err instanceof Error ? err.message : "teardown failed",
      });
    }
  });

  return app;
}

export function startServer(port?: number): Server {
  const config = appConfig();
  const app = createApp({ config });
  return app.listen(port ?? config.port);
}

// Run when executed directly
const isMain =
  process.argv[1]?.endsWith("index.js") ||
  process.argv[1]?.endsWith("index.ts");

if (isMain) {
  const config = appConfig();
  startServer(config.port);
  console.log(`relay listening on :${config.port}`);
}
