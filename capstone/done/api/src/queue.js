// How new orders reach the kitchen: a Redis list that the Python worker reads,
// or, without Redis, a fake kitchen inside the API.
import { createClient } from 'redis';

export const QUEUE_KEY = 'quickbite:orders';

export class RedisQueue {
  constructor(url) {
    this.client = createClient({ url, socket: { connectTimeout: 3000 } });
    this.client.on('error', (err) => console.error('redis:', err.message));
    this.kind = 'redis';
  }
  async init() {
    await this.client.connect();
  }
  async ping() {
    await this.client.ping();
  }
  async push(orderId) {
    await this.client.lPush(QUEUE_KEY, String(orderId));
  }
  async close() {
    await this.client.quit();
  }
}

// Without Redis there is no worker, so the API moves orders along itself.
export class InlineKitchen {
  constructor(store, seconds) {
    this.store = store;
    this.ms = seconds * 1000;
    this.timers = new Set();
    this.kind = 'inline';
  }
  async init() {}
  async ping() {}
  async push(orderId) {
    this.later(() => this.store.setStatus(orderId, 'preparing'), this.ms / 2);
    this.later(() => this.store.setStatus(orderId, 'ready'), this.ms);
  }
  later(fn, ms) {
    const t = setTimeout(() => {
      this.timers.delete(t);
      fn();
    }, ms);
    this.timers.add(t);
  }
  async close() {
    for (const t of this.timers) clearTimeout(t);
  }
}
