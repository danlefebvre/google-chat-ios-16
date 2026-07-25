import { z } from "zod";
import type { NtfyConfig } from "./types.js";

const envSchema = z.object({
  PORT: z.coerce.number().default(8080),
  ADMIN_TOKEN: z.string().min(8),
  RELAY_TOKEN_SECRET: z.string().min(16),
  NTFY_BASE_URL: z.string().url().default("https://ntfy.sh"),
  NTFY_TOPIC: z.string().min(8),
  /** Optional — omit for open/secret-topic ntfy.sh usage without auth. */
  NTFY_ACCESS_TOKEN: z.string().optional(),
  DEEP_LINK_SCHEME: z.string().default("googlechatmulti"),
  /** Optional shared secret for Pub/Sub push verification (`?token=`). */
  PUBSUB_VERIFY_TOKEN: z.string().min(8).optional(),
  GOOGLE_PROJECT_ID: z.string().optional(),
  GOOGLE_PUBSUB_TOPIC: z.string().optional(),
  GOOGLE_OAUTH_CLIENT_ID: z.string().optional(),
  GOOGLE_OAUTH_CLIENT_SECRET: z.string().optional(),
  QUIET_HOURS_START: z.coerce.number().min(0).max(23).optional(),
  QUIET_HOURS_END: z.coerce.number().min(0).max(23).optional(),
  QUIET_HOURS_TZ: z.string().default("UTC"),
  /** JSON file path for durable account storage (survives restarts). */
  ACCOUNT_STORE_PATH: z.string().default("data/accounts.json"),
});

export type AppConfig = {
  port: number;
  adminToken: string;
  tokenSecret: string;
  ntfy: NtfyConfig;
  deepLinkScheme: string;
  accountStorePath: string;
  pubsubVerifyToken?: string;
  google?: {
    projectId: string;
    pubsubTopic: string;
    oauthClientId: string;
    oauthClientSecret: string;
  };
  quietHours: {
    startHour: number;
    endHour: number;
    timeZone: string;
  } | null;
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = envSchema.parse(env);

  const googleReady =
    parsed.GOOGLE_PROJECT_ID &&
    parsed.GOOGLE_PUBSUB_TOPIC &&
    parsed.GOOGLE_OAUTH_CLIENT_ID &&
    parsed.GOOGLE_OAUTH_CLIENT_SECRET;

  const quietHours =
    parsed.QUIET_HOURS_START !== undefined &&
    parsed.QUIET_HOURS_END !== undefined
      ? {
          startHour: parsed.QUIET_HOURS_START,
          endHour: parsed.QUIET_HOURS_END,
          timeZone: parsed.QUIET_HOURS_TZ,
        }
      : null;

  return {
    port: parsed.PORT,
    adminToken: parsed.ADMIN_TOKEN,
    tokenSecret: parsed.RELAY_TOKEN_SECRET,
    accountStorePath: parsed.ACCOUNT_STORE_PATH,
    pubsubVerifyToken: parsed.PUBSUB_VERIFY_TOKEN,
    ntfy: {
      baseUrl: parsed.NTFY_BASE_URL,
      topic: parsed.NTFY_TOPIC,
      accessToken: parsed.NTFY_ACCESS_TOKEN || undefined,
    },
    deepLinkScheme: parsed.DEEP_LINK_SCHEME,
    google: googleReady
      ? {
          projectId: parsed.GOOGLE_PROJECT_ID!,
          pubsubTopic: parsed.GOOGLE_PUBSUB_TOPIC!,
          oauthClientId: parsed.GOOGLE_OAUTH_CLIENT_ID!,
          oauthClientSecret: parsed.GOOGLE_OAUTH_CLIENT_SECRET!,
        }
      : undefined,
    quietHours,
  };
}
