// The HTTP API. Plain node:http, no framework: fewer dependencies, smaller image.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import os from 'node:os';

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' };

function send(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

async function readJson(req) {
  let raw = '';
  for await (const chunk of req) {
    raw += chunk;
    if (raw.length > 10_000) throw new Error('body too large');
  }
  return JSON.parse(raw || '{}');
}

export function createApp({ config, store, queue }) {
  async function handle(req, res) {
    const url = new URL(req.url, 'http://localhost');
    const path = url.pathname;

    if (req.method === 'GET' && path === '/health') {
      const health = { status: 'ok', db: 'ok', queue: 'ok' };
      try {
        await store.ping();
      } catch {
        health.db = 'down';
        health.status = 'degraded';
      }
      try {
        await queue.ping();
      } catch {
        health.queue = 'down';
        health.status = 'degraded';
      }
      return send(res, health.status === 'ok' ? 200 : 503, health);
    }

    if (req.method === 'GET' && path === '/api/info') {
      return send(res, 200, {
        app: 'quickbite-api',
        version: config.version,
        env: config.appEnv,
        store: store.kind,
        queue: queue.kind,
        host: os.hostname(),
      });
    }

    if (req.method === 'GET' && path === '/api/menu') {
      return send(res, 200, await store.menu());
    }

    if (req.method === 'GET' && path === '/api/orders') {
      const limit = Math.min(Number(url.searchParams.get('limit') || 20), 100);
      return send(res, 200, await store.listOrders(limit));
    }

    const match = path.match(/^\/api\/orders\/(\d+)$/);
    if (req.method === 'GET' && match) {
      const order = await store.getOrder(Number(match[1]));
      return order ? send(res, 200, order) : send(res, 404, { error: 'order not found' });
    }

    if (req.method === 'POST' && path === '/api/orders') {
      let body;
      try {
        body = await readJson(req);
      } catch {
        return send(res, 400, { error: 'body must be JSON' });
      }
      const customer = String(body.customer || '').trim();
      if (!customer || customer.length > 60) return send(res, 400, { error: 'customer is required (max 60 chars)' });
      if (!Array.isArray(body.items) || body.items.length === 0) return send(res, 400, { error: 'items is required' });

      const menu = new Map((await store.menu()).map((m) => [Number(m.id), m]));
      const items = [];
      let total = 0;
      for (const line of body.items) {
        const item = menu.get(Number(line.menu_id));
        const qty = line.qty === undefined ? 1 : Number(line.qty);
        if (!item) return send(res, 400, { error: `unknown menu_id ${line.menu_id}` });
        if (!Number.isInteger(qty) || qty < 1 || qty > 20) return send(res, 400, { error: 'qty must be 1..20' });
        items.push({ menu_id: Number(item.id), name: item.name, qty, price: item.price });
        total += item.price * qty;
      }
      const order = await store.createOrder({ customer, items, total });
      await queue.push(order.id);
      return send(res, 201, order);
    }

    // Running without Docker: the API also serves the front end.
    if (req.method === 'GET' && config.webDir && !path.startsWith('/api/')) {
      const file = normalize(join(config.webDir, path === '/' ? 'index.html' : path));
      if (file.startsWith(normalize(config.webDir))) {
        try {
          const data = await readFile(file);
          res.writeHead(200, { 'Content-Type': TYPES[extname(file)] || 'application/octet-stream' });
          return res.end(data);
        } catch {
          /* fall through to 404 */
        }
      }
    }

    return send(res, 404, { error: 'not found' });
  }

  return http.createServer((req, res) => {
    handle(req, res).catch((err) => {
      console.error(err);
      if (!res.headersSent) send(res, 500, { error: 'internal error' });
    });
  });
}
