import { createApp } from "./app.js";
import { loadConfig } from "./config.js";
import { InMemoryStore } from "./store.js";

async function main(): Promise<void> {
  const config = loadConfig();
  const store = new InMemoryStore();
  if (config.quietHours) {
    store.setQuietHours(config.quietHours);
  }

  const app = createApp({
    store,
    ntfy: config.ntfy,
    adminToken: config.adminToken,
    deepLinkScheme: config.deepLinkScheme,
    tokenSecret: config.tokenSecret,
    google: config.google,
  });

  app.listen(config.port, () => {
    console.log(
      `google-chat-ntfy-relay listening on :${config.port} → ${config.ntfy.baseUrl}/${config.ntfy.topic}`,
    );
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
