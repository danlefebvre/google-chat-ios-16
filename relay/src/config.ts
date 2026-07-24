import { z } from "zod";

const envSchema = z.object({
  NTFY_BASE_URL: z.string().url().default("https://ntfy.sh"),
  NTFY_TOPIC: z.string().min(1),
  NTFY_ACCESS_TOKEN: z.string().optional(),
  PORT: z.coerce.number().int().positive().default(8080),
  DEEP_LINK_SCHEME: z.string().default("gchatmulti"),
});

export type RelayConfig = {
  ntfy: {
    baseUrl: string;
    topic: string;
    accessToken?: string;
  };
  port: number;
  deepLinkScheme: string;
};

export function loadConfig(env: Record<string, string | undefined> = process.env): RelayConfig {
  const parsed = envSchema.parse(env);
  return {
    ntfy: {
      baseUrl: parsed.NTFY_BASE_URL.replace(/\/$/, ""),
      topic: parsed.NTFY_TOPIC,
      accessToken: parsed.NTFY_ACCESS_TOKEN,
    },
    port: parsed.PORT,
    deepLinkScheme: parsed.DEEP_LINK_SCHEME,
  };
}
