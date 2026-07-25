import { timingSafeEqual } from "node:crypto";
import express, { type Express, type Request, type Response } from "express";
import helmet from "helmet";
import { AccountService } from "./accounts.js";
import { createTokenCrypto } from "./crypto.js";
import {
  createGoogleAccountOwnershipVerifier,
  createGoogleEventsClient,
  type AccountOwnershipVerifier,
} from "./google.js";
import { formatNtfyNotification, NtfyPublisher } from "./ntfy.js";
import { handlePubSubPush, type PubSubPushBody } from "./pubsub.js";
import { renewExpiringSubscriptions } from "./renewal.js";
import type { AccountStore } from "./store.js";
import type { EventsClient, NtfyConfig } from "./types.js";

export type CreateAppOptions = {
  store: AccountStore;
  ntfy: NtfyConfig;
  adminToken: string;
  deepLinkScheme?: string;
  /** Required; tests pass an explicit secret (never hardcode in production). */
  tokenSecret: string;
  /** When set, `/pubsub/push` requires matching `?token=` (or `X-Goog-Channel-Token`). */
  pubsubVerifyToken?: string;
  eventsClient?: EventsClient;
  /** Override Google ownership checks (tests). */
  verifyAccountOwnership?: AccountOwnershipVerifier;
  google?: {
    projectId: string;
    pubsubTopic: string;
    oauthClientId: string;
    oauthClientSecret?: string;
  };
};

function unconfiguredEventsClient(): EventsClient {
  const fail = async () => {
    throw new Error("Google events client not configured");
  };
  return {
    createSubscription: fail,
    renewSubscription: fail,
    deleteSubscription: fail,
    revokeToken: fail,
  };
}


function secretsEqual(left: string, right: string): boolean {
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  if (a.length !== b.length) {
    // Consume comparable work without throwing on length mismatch.
    timingSafeEqual(a, a);
    return false;
  }
  return timingSafeEqual(a, b);
}

function bearerToken(req: Request): string {
  const header = req.header("authorization") ?? "";
  return header.startsWith("Bearer ") ? header.slice(7) : "";
}

export function createApp(options: CreateAppOptions): Express {
  const app = express();
  app.use(helmet());
  app.use(express.json({ limit: "1mb" }));

  const publisher = new NtfyPublisher(options.ntfy);
  if (!options.tokenSecret) {
    throw new Error("tokenSecret is required");
  }
  const crypto = createTokenCrypto(options.tokenSecret);
  const events =
    options.eventsClient ??
    (options.google
      ? createGoogleEventsClient(options.google)
      : unconfiguredEventsClient());

  const accounts = new AccountService({
    store: options.store,
    events,
    crypto,
  });

  const verifyAccountOwnership: AccountOwnershipVerifier | undefined =
    options.verifyAccountOwnership ??
    (options.google
      ? createGoogleAccountOwnershipVerifier({
          oauthClientId: options.google.oauthClientId,
          oauthClientSecret: options.google.oauthClientSecret,
        })
      : undefined);

  app.get("/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      service: "google-chat-ntfy-relay",
      time: new Date().toISOString(),
      accounts: options.store.listAccounts().length,
    });
  });

  app.post("/pubsub/push", async (req: Request, res: Response) => {
    try {
      if (options.pubsubVerifyToken) {
        const queryToken =
          typeof req.query.token === "string" ? req.query.token : "";
        const headerToken = req.header("x-goog-channel-token") ?? "";
        if (
          !secretsEqual(queryToken, options.pubsubVerifyToken) &&
          !secretsEqual(headerToken, options.pubsubVerifyToken)
        ) {
          res.status(401).json({ error: "unauthorized" });
          return;
        }
      }
      const result = await handlePubSubPush({
        body: req.body as PubSubPushBody,
        store: options.store,
        publisher,
        deepLinkScheme: options.deepLinkScheme,
      });
      if (result.status === 400) {
        res.status(400).json({ error: "invalid_pubsub_payload" });
        return;
      }
      res.status(204).end();
    } catch (err) {
      console.error("pubsub handler error", err);
      res.status(500).json({ error: "publish_failed" });
    }
  });

  // User-scoped account lifecycle — authenticated by the caller's Google
  // refresh token (never the shared ADMIN_TOKEN). Keep ADMIN_TOKEN server-side.
  app.post("/accounts", async (req, res) => {
    try {
      const { accountId, email, label, refreshToken } = req.body ?? {};
      if (!accountId || !email || !label || !refreshToken) {
        res.status(400).json({ error: "missing_fields" });
        return;
      }
      if (!verifyAccountOwnership) {
        res.status(503).json({ error: "ownership_verification_unavailable" });
        return;
      }
      const ownsToken = await verifyAccountOwnership({
        accountId,
        email,
        refreshToken,
      });
      if (!ownsToken) {
        res.status(403).json({ error: "ownership_mismatch" });
        return;
      }
      const { account, relayCredential } = await accounts.registerAccount({
        accountId,
        email,
        label,
        refreshToken,
      });
      res.status(201).json({
        accountId: account.accountId,
        subscriptionName: account.subscriptionName,
        relayCredential,
      });
    } catch (err) {
      console.error("register account failed", err);
      const detail = err instanceof Error ? err.message : String(err);
      res.status(500).json({ error: "register_failed", detail });
    }
  });

  // Prefer ?accountId=… — path params break on issuer URLs that contain `/`
  // (https://accounts.google.com|sub). Keep :accountId for simple legacy ids.
  const handleAccountDelete = async (
    req: Request,
    res: Response,
    accountIdRaw: string | undefined,
  ) => {
    try {
      const accountId = accountIdRaw ? decodeURIComponent(accountIdRaw) : "";
      if (!accountId) {
        res.status(400).json({ error: "missing_account_id" });
        return;
      }
      const relayCredential =
        bearerToken(req) || (req.body?.relayCredential as string | undefined);
      if (!relayCredential) {
        res.status(401).json({ error: "unauthorized" });
        return;
      }
      if (!accounts.ownsRelayCredential(accountId, relayCredential)) {
        res.status(403).json({ error: "forbidden" });
        return;
      }
      await accounts.removeAccount(accountId);
      res.status(204).end();
    } catch (err) {
      console.error("remove account failed", err);
      res.status(500).json({ error: "remove_failed" });
    }
  };

  app.delete("/accounts", async (req, res) => {
    const accountId =
      typeof req.query.accountId === "string" ? req.query.accountId : undefined;
    await handleAccountDelete(req, res, accountId);
  });

  app.delete("/accounts/:accountId", async (req, res) => {
    await handleAccountDelete(req, res, req.params.accountId);
  });

  app.use("/admin", (req, res, next) => {
    const token = bearerToken(req);
    if (!secretsEqual(token, options.adminToken)) {
      res.status(401).json({ error: "unauthorized" });
      return;
    }
    next();
  });

  app.post("/admin/test-ntfy", async (req, res) => {
    try {
      const {
        accountLabel = "Test",
        spaceTitle = "manual",
        senderName = "Relay",
        messageText = "test notification",
      } = req.body ?? {};

      const formatted = formatNtfyNotification({
        accountLabel,
        spaceTitle,
        senderName,
        messageText,
      });

      await publisher.publish({
        title: formatted.title,
        body: formatted.body,
        tags: ["white_check_mark"],
      });

      res.status(200).json({ ok: true });
    } catch (err) {
      console.error("test-ntfy publish failed", err);
      res.status(502).json({ error: "publish_failed" });
    }
  });

  app.get("/admin/accounts", (_req, res) => {
    const list = options.store.listAccounts().map((a) => ({
      accountId: a.accountId,
      email: a.email,
      label: a.label,
      subscriptionName: a.subscriptionName,
      subscriptionExpireTime: a.subscriptionExpireTime,
      ntfyBindingActive: a.ntfyBindingActive,
      muted: a.muted,
      mutedSpaces: a.mutedSpaces,
      createdAt: a.createdAt,
    }));
    res.status(200).json({ accounts: list });
  });

  app.post("/admin/accounts", async (req, res) => {
    try {
      const { accountId, email, label, refreshToken } = req.body ?? {};
      if (!accountId || !email || !label || !refreshToken) {
        res.status(400).json({ error: "missing_fields" });
        return;
      }
      const { account, relayCredential } = await accounts.registerAccount({
        accountId,
        email,
        label,
        refreshToken,
      });
      res.status(201).json({
        accountId: account.accountId,
        subscriptionName: account.subscriptionName,
        relayCredential,
      });
    } catch (err) {
      console.error("register account failed", err);
      res.status(500).json({ error: "register_failed" });
    }
  });

  app.delete("/admin/accounts/:accountId", async (req, res) => {
    try {
      await accounts.removeAccount(decodeURIComponent(req.params.accountId));
      res.status(204).end();
    } catch (err) {
      console.error("remove account failed", err);
      res.status(500).json({ error: "remove_failed" });
    }
  });

  app.post("/admin/accounts/:accountId/mute", (req, res) => {
    try {
      const muted = Boolean(req.body?.muted);
      accounts.setAccountMuted(decodeURIComponent(req.params.accountId), muted);
      res.status(200).json({ ok: true, muted });
    } catch {
      res.status(404).json({ error: "unknown_account" });
    }
  });

  app.post("/admin/accounts/:accountId/spaces/mute", (req, res) => {
    try {
      const spaceName = req.body?.spaceName as string | undefined;
      const muted = Boolean(req.body?.muted);
      if (!spaceName) {
        res.status(400).json({ error: "missing_spaceName" });
        return;
      }
      accounts.setSpaceMuted(
        decodeURIComponent(req.params.accountId),
        spaceName,
        muted,
      );
      res.status(200).json({ ok: true, spaceName, muted });
    } catch {
      res.status(404).json({ error: "unknown_account" });
    }
  });

  app.put("/admin/quiet-hours", (req, res) => {
    const { startHour, endHour, timeZone = "UTC", enabled } = req.body ?? {};
    if (enabled === false) {
      options.store.setQuietHours(null);
      res.status(200).json({ quietHours: null });
      return;
    }
    if (
      typeof startHour !== "number" ||
      typeof endHour !== "number" ||
      startHour < 0 ||
      startHour > 23 ||
      endHour < 0 ||
      endHour > 23
    ) {
      res.status(400).json({ error: "invalid_quiet_hours" });
      return;
    }
    const quiet = { startHour, endHour, timeZone: String(timeZone) };
    options.store.setQuietHours(quiet);
    res.status(200).json({ quietHours: quiet });
  });

  app.post("/admin/renew-subscriptions", async (req, res) => {
    try {
      const horizonHours =
        typeof req.body?.horizonHours === "number" ? req.body.horizonHours : 24;
      const result = await renewExpiringSubscriptions({
        store: options.store,
        events,
        crypto,
        horizonMs: horizonHours * 60 * 60 * 1000,
        alertRenewFailure: async ({ accountId, error }) => {
          console.error("subscription renew failed", accountId, error);
          try {
            await publisher.publish({
              title: "[Relay] subscription renew failed",
              body: `account ${accountId}: ${error instanceof Error ? error.message : "error"}`,
              tags: ["warning"],
            });
          } catch (publishError) {
            console.error("failed to alert renew failure", publishError);
          }
        },
      });
      res.status(200).json(result);
    } catch (err) {
      console.error("renew-subscriptions failed", err);
      res.status(500).json({ error: "renew_failed" });
    }
  });

  return app;
}
