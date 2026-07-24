import { createServer } from "http";
import { createServer as createRelayServer } from "./server.js";
import type { NtfyConfig } from "./types.js";

const VERSION = "0.1.0";

function loadNtfyConfig(): NtfyConfig {
  const topic = process.env.NTFY_TOPIC;
  if (!topic) {
    throw new Error("NTFY_TOPIC environment variable is required");
  }

  return {
    baseUrl: process.env.NTFY_BASE_URL ?? "https://ntfy.sh",
    topic,
    accessToken: process.env.NTFY_ACCESS_TOKEN,
  };
}

async function requestToFetchArgs(
  req: import("http").IncomingMessage,
): Promise<{ url: string; init: RequestInit }> {
  const host = req.headers.host ?? "localhost";
  const url = `http://${host}${req.url ?? "/"}`;
  const chunks: Buffer[] = [];

  for await (const chunk of req) {
    chunks.push(chunk as Buffer);
  }

  const body = chunks.length > 0 ? Buffer.concat(chunks) : undefined;
  const headers = new Headers();
  for (const [key, value] of Object.entries(req.headers)) {
    if (value) {
      headers.set(key, Array.isArray(value) ? value.join(", ") : value);
    }
  }

  const init: RequestInit = { method: req.method, headers };
  if (body && req.method !== "GET" && req.method !== "HEAD") {
    init.body = body;
  }

  return { url, init };
}

export function main(): void {
  const port = Number(process.env.PORT ?? 8080);
  const ntfyConfig = loadNtfyConfig();
  const relay = createRelayServer({ version: VERSION, ntfyConfig });

  createServer(async (req, res) => {
    try {
      const { url, init } = await requestToFetchArgs(req);
      const response = await relay.fetch(new Request(url, init));
      res.statusCode = response.status;
      response.headers.forEach((value, key) => res.setHeader(key, value));
      res.end(await response.text());
    } catch (err) {
      const message = err instanceof Error ? err.message : "internal error";
      res.statusCode = 500;
      res.end(message);
    }
  }).listen(port, () => {
    console.log(`relay listening on :${port}`);
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
