"""Products live in PostgreSQL (or SQLite when you run without containers)."""
import os
import sqlite3
import threading
from pathlib import Path

# app/api/seed.sql locally, /app/seed.sql in the image
SEED_FILE = Path(os.getenv("SEED_FILE", Path(__file__).resolve().parents[1] / "seed.sql"))


class ProductStore:
    def __init__(self, database_url: str):
        self.url = database_url
        self._lock = threading.Lock()
        self.kind = "postgres" if database_url.startswith("postgres") else "sqlite"
        if self.kind == "sqlite":
            path = database_url.removeprefix("sqlite:///") or ":memory:"
            self._sqlite = sqlite3.connect(path, check_same_thread=False)
            self._sqlite.row_factory = sqlite3.Row
            if self._sqlite.execute(
                "SELECT count(*) FROM sqlite_master WHERE name='products'"
            ).fetchone()[0] == 0 and SEED_FILE.exists():
                self._sqlite.executescript(SEED_FILE.read_text())

    def _query(self, sql: str, params: tuple = ()) -> list[dict]:
        if self.kind == "sqlite":
            with self._lock:
                rows = self._sqlite.execute(sql.replace("%s", "?"), params).fetchall()
            return [dict(r) for r in rows]
        import psycopg
        from psycopg.rows import dict_row

        with psycopg.connect(self.url, row_factory=dict_row, connect_timeout=3) as conn:
            return list(conn.execute(sql, params).fetchall())

    def list_products(self) -> list[dict]:
        return self._query("SELECT * FROM products ORDER BY id")

    def get_product(self, product_id: int) -> dict | None:
        rows = self._query("SELECT * FROM products WHERE id = %s", (product_id,))
        return rows[0] if rows else None

    def ping(self) -> None:
        self._query("SELECT 1 AS ok")
