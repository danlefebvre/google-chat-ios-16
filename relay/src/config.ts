export interface NtfyConfig {
  baseUrl: string;
  topic: string;
  accessToken?: string;
}

export interface RelayConfig extends NtfyConfig {
  port: number;
  deepLinkScheme?: string;
}

export function loadConfigFromEnv(): RelayConfig {
  const port = Number(process.env.PORT ?? "8080");
  const ntfyBaseUrl = process.env.NTFY_BASE_URL ?? "https://ntfy.sh";
  const ntfyTopic = process.env.NTFY_TOPIC;
  if (!ntfyTopic) {
    throw new Error("NTFY_TOPIC is required");
  }

  return {
    port,
    baseUrl: ntfyBaseUrl,
    topic: ntfyTopic,
    accessToken: process.env.NTFY_ACCESS_TOKEN,
    deepLinkScheme: process.env.DEEP_LINK_SCHEME ?? "gchatmulti",
  };
}
