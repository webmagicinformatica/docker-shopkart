// Where orders live: PostgreSQL in the real stack, memory when PGHOST isn't set.
import pg from 'pg';
import { MENU } from './menu.js';

export const STATUSES = ['received', 'preparing', 'ready'];

const SCHEMA = `
CREATE TABLE IF NOT EXISTS menu (
  id    INTEGER PRIMARY KEY,
  name  TEXT    NOT NULL,
  price INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS orders (
  id          SERIAL PRIMARY KEY,
  customer    TEXT        NOT NULL,
  items       JSONB       NOT NULL,
  total       INTEGER     NOT NULL,
  status      TEXT        NOT NULL DEFAULT 'received',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);`;

export class MemoryStore {
  constructor() {
    this.orders = new Map();
    this.nextId = 1;
    this.kind = 'memory';
  }
  async init() {}
  async ping() {}
  async menu() {
    return MENU;
  }
  async createOrder({ customer, items, total }) {
    const now = new Date().toISOString();
    const order = { id: this.nextId++, customer, items, total, status: 'received', created_at: now, updated_at: now };
    this.orders.set(order.id, order);
    return { ...order };
  }
  async getOrder(id) {
    const order = this.orders.get(id);
    return order ? { ...order } : null;
  }
  async listOrders(limit) {
    return [...this.orders.values()].sort((a, b) => b.id - a.id).slice(0, limit).map((o) => ({ ...o }));
  }
  async setStatus(id, status) {
    const order = this.orders.get(id);
    if (order) {
      order.status = status;
      order.updated_at = new Date().toISOString();
    }
  }
  async close() {}
}

export class PgStore {
  constructor(options) {
    this.pool = new pg.Pool({ ...options, max: 5, connectionTimeoutMillis: 3000 });
    this.kind = 'postgres';
  }
  // Create the tables and the menu once; safe to run on every start.
  async init() {
    await this.pool.query(SCHEMA);
    for (const item of MENU) {
      await this.pool.query('INSERT INTO menu (id, name, price) VALUES ($1, $2, $3) ON CONFLICT (id) DO NOTHING', [
        item.id,
        item.name,
        item.price,
      ]);
    }
  }
  async ping() {
    await this.pool.query('SELECT 1');
  }
  async menu() {
    const { rows } = await this.pool.query('SELECT id, name, price FROM menu ORDER BY id');
    return rows;
  }
  async createOrder({ customer, items, total }) {
    const { rows } = await this.pool.query(
      'INSERT INTO orders (customer, items, total) VALUES ($1, $2, $3) RETURNING *',
      [customer, JSON.stringify(items), total],
    );
    return rows[0];
  }
  async getOrder(id) {
    const { rows } = await this.pool.query('SELECT * FROM orders WHERE id = $1', [id]);
    return rows[0] || null;
  }
  async listOrders(limit) {
    const { rows } = await this.pool.query('SELECT * FROM orders ORDER BY id DESC LIMIT $1', [limit]);
    return rows;
  }
  async setStatus(id, status) {
    await this.pool.query('UPDATE orders SET status = $2, updated_at = now() WHERE id = $1', [id, status]);
  }
  async close() {
    await this.pool.end();
  }
}
