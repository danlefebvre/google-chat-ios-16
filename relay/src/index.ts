import { createApp } from "./app.js";
import { loadConfigFromEnv } from "./config.js";

export function main(): void {
  const config = loadConfigFromEnv();
  const app = createApp(config);

  app.listen(config.port, () => {
    console.log(`relay listening on :${config.port}`);
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
