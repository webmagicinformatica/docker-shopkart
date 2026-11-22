// API tests: in-memory store and fake kitchen, so no database, Redis or network needed.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { MemoryStore } from '../src/store.js';
import { InlineKitchen } from '../src/queue.js';

let server;
let base;
const store = new MemoryStore();
const kitchen = new InlineKitchen(store, 0.2);

before(async () => {
  const config = loadConfig({ APP_VERSION: 'test' });
  server = createApp({ config, store, queue: kitchen });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await kitchen.close();
  await new Promise((resolve) => server.close(resolve));
});

const post = (path, body) =>
  fetch(base + path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

test('health is ok', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: 'ok', db: 'ok', queue: 'ok' });
});

test('info reports version and backends', async () => {
  const info = await (await fetch(`${base}/api/info`)).json();
  assert.equal(info.version, 'test');
  assert.equal(info.store, 'memory');
  assert.equal(info.queue, 'inline');
});

test('menu has six dishes', async () => {
  const menu = await (await fetch(`${base}/api/menu`)).json();
  assert.equal(menu.length, 6);
  assert.equal(menu[0].name, 'Masala Dosa');
});

test('an order is priced and stored', async () => {
  const res = await post('/api/orders', { customer: 'Asha', items: [{ menu_id: 1, qty: 2 }, { menu_id: 6 }] });
  assert.equal(res.status, 201);
  const order = await res.json();
  assert.equal(order.total, 120 * 2 + 60);
  assert.equal(order.status, 'received');
  const again = await (await fetch(`${base}/api/orders/${order.id}`)).json();
  assert.equal(again.customer, 'Asha');
});

test('the kitchen makes the order ready', async () => {
  const order = await (await post('/api/orders', { customer: 'Ravi', items: [{ menu_id: 3 }] })).json();
  await new Promise((r) => setTimeout(r, 400));
  const done = await (await fetch(`${base}/api/orders/${order.id}`)).json();
  assert.equal(done.status, 'ready');
});

test('recent orders, newest first', async () => {
  const orders = await (await fetch(`${base}/api/orders?limit=5`)).json();
  assert.ok(orders.length >= 2);
  assert.ok(orders[0].id > orders[1].id);
});

test('bad orders are rejected', async () => {
  assert.equal((await post('/api/orders', { items: [{ menu_id: 1 }] })).status, 400);
  assert.equal((await post('/api/orders', { customer: 'X', items: [] })).status, 400);
  assert.equal((await post('/api/orders', { customer: 'X', items: [{ menu_id: 99 }] })).status, 400);
  assert.equal((await post('/api/orders', { customer: 'X', items: [{ menu_id: 1, qty: 0 }] })).status, 400);
  assert.equal((await fetch(`${base}/api/orders/9999`)).status, 404);
});

test('a password file wins over the variable', async () => {
  const { writeFileSync, mkdtempSync } = await import('node:fs');
  const { join } = await import('node:path');
  const { tmpdir } = await import('node:os');
  const file = join(mkdtempSync(join(tmpdir(), 'qb-')), 'pw');
  writeFileSync(file, 's3cret\n');
  const config = loadConfig({ PGHOST: 'db', PGPASSWORD: 'plain', PGPASSWORD_FILE: file });
  assert.equal(config.pg.password, 's3cret');
  assert.equal(loadConfig({}).pg, null);
});
