import { z } from "zod";
import type { BarkConfig } from "./types.js";

const envSchema = z.object({
  PORT: z.coerce.number().default(8080),
  ADMIN_TOKEN: z.string().min(8),
  RELAY_TOKEN_SECRET: z.string().min(16),
  /** Official Bark API host, or your self-hosted bark-server. */
  BARK_BASE_URL: z.string().url().default("https://api.day.app"),
  /** Device key from the Bark iOS app (the path segment after api.day.app/). */
  BARK_DEVICE_KEY: z.string().min(8),
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
  bark: BarkConfig;
  deepLinkScheme: string;
  accountStorePath: string;
  pubsubVerifyToken?: string;
  google?: {
    projectId: string;
    pubsubTopic: string;
    /** Must match the client that issued refresh tokens (iOS GIDClientID). */
    oauthClientId: string;
    /** Optional — only for Web OAuth clients. */
    oauthClientSecret?: string;
  };
  quietHours: {
    startHour: number;
    endHour: number;
    timeZone: string;
  } | null;
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = envSchema.parse(env);

  // Secret is optional so iOS OAuth clients (no secret) can refresh tokens.
  const googleReady =
    parsed.GOOGLE_PROJECT_ID &&
    parsed.GOOGLE_PUBSUB_TOPIC &&
    parsed.GOOGLE_OAUTH_CLIENT_ID;

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
    bark: {
      baseUrl: parsed.BARK_BASE_URL,
      deviceKey: parsed.BARK_DEVICE_KEY,
    },
    deepLinkScheme: parsed.DEEP_LINK_SCHEME,
    google: googleReady
      ? {
          projectId: parsed.GOOGLE_PROJECT_ID!,
          pubsubTopic: parsed.GOOGLE_PUBSUB_TOPIC!,
          oauthClientId: parsed.GOOGLE_OAUTH_CLIENT_ID!,
          oauthClientSecret: parsed.GOOGLE_OAUTH_CLIENT_SECRET || undefined,
        }
      : undefined,
    quietHours,
  };
}
