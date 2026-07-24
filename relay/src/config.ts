import type { AppConfig, RelayConfig } from "./types.js";

const REQUIRED = ["NTFY_TOPIC", "NTFY_SERVER"] as const;

export function loadConfig(
  env: Record<string, string | undefined> = process.env,
): RelayConfig {
  for (const key of REQUIRED) {
    if (!env[key]) {
      throw new Error(`Missing required environment variable: ${key}`);
    }
  }

  const server = env.NTFY_SERVER!.replace(/\/$/, "");

  return {
    ntfy: {
      server,
      topic: env.NTFY_TOPIC!,
      accessToken: env.NTFY_ACCESS_TOKEN,
    },
    google: {
      projectId: env.GOOGLE_CLOUD_PROJECT,
      clientId: env.GOOGLE_CLIENT_ID,
      clientSecret: env.GOOGLE_CLIENT_SECRET,
    },
    pubsub: {
      subscription: env.PUBSUB_SUBSCRIPTION,
    },
    port: env.PORT ? Number(env.PORT) : 8080,
    quietHours: parseQuietHours(env),
  };
}

function parseQuietHours(
  env: Record<string, string | undefined>,
): RelayConfig["quietHours"] {
  if (!env.QUIET_HOURS_START || !env.QUIET_HOURS_END) {
    return null;
  }
  return {
    startHour: Number(env.QUIET_HOURS_START),
    endHour: Number(env.QUIET_HOURS_END),
    timezone: env.QUIET_HOURS_TZ ?? "UTC",
  };
}

export function appConfig(version = "0.1.0"): AppConfig {
  return { ...loadConfig(), version };
}
