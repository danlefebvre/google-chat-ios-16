import { z } from "zod";
import type { NtfyConfig } from "./types.js";

const envSchema = z.object({
  PORT: z.coerce.number().default(8080),
  ADMIN_TOKEN: z.string().min(8),
  RELAY_TOKEN_SECRET: z.string().min(16),
  NTFY_BASE_URL: z.string().url().default("https://ntfy.sh"),
  NTFY_TOPIC: z.string().min(8),
  NTFY_ACCESS_TOKEN: z.string().min(1),
  DEEP_LINK_SCHEME: z.string().default("googlechatmulti"),
  GOOGLE_PROJECT_ID: z.string().optional(),
  GOOGLE_PUBSUB_TOPIC: z.string().optional(),
  GOOGLE_OAUTH_CLIENT_ID: z.string().optional(),
  GOOGLE_OAUTH_CLIENT_SECRET: z.string().optional(),
  QUIET_HOURS_START: z.coerce.number().min(0).max(23).optional(),
  QUIET_HOURS_END: z.coerce.number().min(0).max(23).optional(),
  QUIET_HOURS_TZ: z.string().default("UTC"),
});

export type AppConfig = {
  port: number;
  adminToken: string;
  tokenSecret: string;
  ntfy: NtfyConfig;
  deepLinkScheme: string;
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
    ntfy: {
      baseUrl: parsed.NTFY_BASE_URL,
      topic: parsed.NTFY_TOPIC,
      accessToken: parsed.NTFY_ACCESS_TOKEN,
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
