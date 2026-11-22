// Entry point: wire config, store and queue together, then listen.
import { loadConfig } from './config.js';
import { createApp } from './app.js';
import { MemoryStore, PgStore } from './store.js';
import { InlineKitchen, RedisQueue } from './queue.js';

const config = loadConfig();
const store = config.pg ? new PgStore(config.pg) : new MemoryStore();
const queue = config.redisUrl ? new RedisQueue(config.redisUrl) : new InlineKitchen(store, config.kitchenSeconds);

await store.init();
await queue.init();

const server = createApp({ config, store, queue });
server.listen(config.port, '0.0.0.0', () => {
  console.log(`quickbite-api ${config.version} (${config.appEnv}) on :${config.port}, store=${store.kind}, queue=${queue.kind}`);
});

// docker stop sends SIGTERM: finish in-flight requests, close connections, exit 0.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    console.log(`${signal} received, shutting down`);
    server.close(async () => {
      await queue.close();
      await store.close();
      process.exit(0);
    });
    setTimeout(() => process.exit(0), 5000).unref();
  });
}
