import { createServer } from "node:http";
import { createApp } from "./app.js";
import { loadConfig } from "./config.js";
import { FileAccountStore } from "./store.js";

async function main(): Promise<void> {
  const config = loadConfig();
  // File-backed so linked accounts / subscriptions survive restarts.
  // For multi-replica production, point ACCOUNT_STORE_PATH at a shared volume
  // or swap this for Firestore/SQLite.
  const store = new FileAccountStore(config.accountStorePath);
  if (config.quietHours) {
    store.setQuietHours(config.quietHours);
  }

  const app = createApp({
    store,
    ntfy: config.ntfy,
    adminToken: config.adminToken,
    deepLinkScheme: config.deepLinkScheme,
    tokenSecret: config.tokenSecret,
    pubsubVerifyToken: config.pubsubVerifyToken,
    google: config.google,
  });

  // Explicit timeouts (from PR #8 Go relay pattern) to mitigate Slowloris-style hangs.
  const server = createServer(app);
  server.requestTimeout = 30_000;
  server.headersTimeout = 15_000;
  server.keepAliveTimeout = 65_000;
  server.timeout = 60_000;

  server.listen(config.port, () => {
    console.log(
      `google-chat-ntfy-relay listening on :${config.port} → ${config.ntfy.baseUrl}/<topic>`,
    );
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
