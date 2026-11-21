-- ShopKart seed data. Works on PostgreSQL (in a container) and on SQLite (local run).
CREATE TABLE IF NOT EXISTS products (
    id        INTEGER PRIMARY KEY,
    name      TEXT    NOT NULL,
    category  TEXT    NOT NULL,
    price_inr INTEGER NOT NULL,
    stock     INTEGER NOT NULL DEFAULT 0
);

INSERT INTO products (id, name, category, price_inr, stock) VALUES
    (1, 'Cotton Kurta',          'Clothing',    899,  40),
    (2, 'Running Shoes',         'Footwear',   2499,  25),
    (3, 'Steel Water Bottle',    'Home',        549, 120),
    (4, 'Wireless Earbuds',      'Electronics',1799,  60),
    (5, 'Masala Chai Tin',       'Grocery',     299, 200),
    (6, 'Laptop Backpack',       'Bags',       1499,  35),
    (7, 'LED Desk Lamp',         'Home',        999,  50),
    (8, 'Yoga Mat',              'Fitness',     749,  80)
ON CONFLICT (id) DO NOTHING;
