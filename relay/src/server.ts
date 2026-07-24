import { healthResponse } from "./health.js";
import { formatNotification } from "./format-notification.js";
import { publishToNtfy } from "./ntfy.js";
import { handlePubSubMessage } from "./pubsub-handler.js";
import type { AccountStore } from "./store.js";
import { InMemoryAccountStore } from "./store.js";
import type { NtfyConfig, NotificationPayload, FormatNotificationInput, MuteConfig } from "./types.js";

export interface ServerOptions {
  version: string;
  ntfyConfig?: NtfyConfig;
  publish?: (notification: NotificationPayload) => Promise<void>;
  accounts?: AccountStore;
  muteConfig?: MuteConfig;
}

interface PubSubPushBody {
  message?: { data?: string };
  subscription?: string;
}

export function createServer(options: ServerOptions) {
  const accounts = options.accounts ?? new InMemoryAccountStore();
  const muteConfig: MuteConfig = options.muteConfig ?? {
    mutedAccounts: [],
    mutedSpaces: [],
    quietHours: null,
  };

  const publish =
    options.publish ??
    (async (notification: NotificationPayload) => {
      if (!options.ntfyConfig) {
        throw new Error("ntfy config required");
      }
      await publishToNtfy(options.ntfyConfig, notification);
    });

  return {
    async fetch(request: Request): Promise<Response> {
      const url = new URL(request.url);

      if (request.method === "GET" && url.pathname === "/health") {
        return Response.json(healthResponse(options.version));
      }

      if (request.method === "POST" && url.pathname === "/test-notify") {
        try {
          const body = (await request.json()) as FormatNotificationInput;
          const notification = formatNotification(body);
          await publish(notification);
          return Response.json({ ok: true, notification });
        } catch (err) {
          const message = err instanceof Error ? err.message : "unknown error";
          return Response.json({ ok: false, error: message }, { status: 500 });
        }
      }

      if (request.method === "POST" && url.pathname === "/pubsub") {
        try {
          const body = (await request.json()) as PubSubPushBody;
          const subscription = body.subscription;
          const allAccounts = await accounts.list();
          const account = subscription
            ? allAccounts.find((a) => a.subscriptionName === subscription)
            : allAccounts[0];

          if (!account || !body.message) {
            return new Response(null, { status: 204 });
          }

          await handlePubSubMessage(body, account, {
            publish,
            muteConfig,
            now: new Date(),
          });
          return new Response(null, { status: 204 });
        } catch (err) {
          const message = err instanceof Error ? err.message : "unknown error";
          return Response.json({ ok: false, error: message }, { status: 500 });
        }
      }

      return new Response("Not Found", { status: 404 });
    },
  };
}
