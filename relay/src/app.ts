import express from "express";
import type { RelayConfig } from "./config.js";
import { buildNtfyPayload, publishToNtfy } from "./ntfy.js";
import { handlePubSubPush } from "./pubsub.js";
import type { RelayServices } from "./pubsub.js";
import { shouldDeliverNotification } from "./mutes.js";
import type { MuteConfig } from "./mutes.js";
import type { AccountStore } from "./accounts.js";

export interface AppDependencies {
  config: RelayConfig;
  muteConfig: MuteConfig;
  accountStore: AccountStore;
}

export function createRelayServices(deps: AppDependencies): RelayServices {
  return {
    getAccountBySubscription(subscriptionName) {
      // Resolved synchronously from in-memory cache in createApp
      return null;
    },
    shouldDeliver(context) {
      return shouldDeliverNotification(deps.muteConfig, context);
    },
    async publishNotification(input) {
      const payload = buildNtfyPayload({
        ...input,
        deepLinkScheme: deps.config.deepLinkScheme,
      });
      await publishToNtfy(
        {
          baseUrl: deps.config.baseUrl,
          topic: deps.config.topic,
          accessToken: deps.config.accessToken,
        },
        payload,
      );
    },
  };
}

export function createApp(config: RelayConfig, deps?: Partial<AppDependencies>) {
  const app = express();
  app.use(express.json());

  const muteConfig: MuteConfig =
    deps?.muteConfig ?? {
      mutedAccounts: new Set(),
      mutedSpaces: new Set(),
      quietHours: null,
    };

  const accountStore = deps?.accountStore;
  const subscriptionIndex = new Map<
    string,
    { id: string; label: string }
  >();

  if (accountStore) {
    void accountStore.list().then((accounts) => {
      for (const account of accounts) {
        subscriptionIndex.set(account.subscriptionName, {
          id: account.id,
          label: account.label,
        });
      }
    });
  }

  const services: RelayServices = {
    getAccountBySubscription(subscriptionName) {
      return subscriptionIndex.get(subscriptionName) ?? null;
    },
    shouldDeliver(context) {
      return shouldDeliverNotification(muteConfig, context);
    },
    async publishNotification(input) {
      const payload = buildNtfyPayload({
        ...input,
        deepLinkScheme: config.deepLinkScheme,
      });
      await publishToNtfy(
        {
          baseUrl: config.baseUrl,
          topic: config.topic,
          accessToken: config.accessToken,
        },
        payload,
      );
    },
  };

  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  app.post("/pubsub/push", async (req, res) => {
    try {
      await handlePubSubPush(services, req.body);
      res.status(204).send();
    } catch (error) {
      console.error("pubsub push failed", error);
      res.status(500).json({ error: "push handling failed" });
    }
  });

  app.post("/test/notify", async (req, res) => {
    const { accountLabel, spaceTitle, senderName, messagePreview, spaceResourceName } =
      req.body as {
        accountLabel?: string;
        spaceTitle?: string;
        senderName?: string;
        messagePreview?: string;
        spaceResourceName?: string;
      };

    if (!accountLabel || !spaceTitle || !senderName || !messagePreview) {
      res.status(400).json({ error: "missing required fields" });
      return;
    }

    try {
      await services.publishNotification({
        accountLabel,
        spaceTitle,
        senderName,
        messagePreview,
        spaceResourceName,
      });
      res.status(204).send();
    } catch (error) {
      console.error("test notify failed", error);
      res.status(502).json({ error: "ntfy publish failed" });
    }
  });

  return app;
}
