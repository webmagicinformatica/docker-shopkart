"""Create and seed the products table, then exit. Safe to run more than once.

    python -m shopkart_api.seed          (uses DATABASE_URL, like the API)
"""
from .config import load_settings
from .db import SEED_FILE


def main() -> None:
    settings = load_settings()
    if settings.db_kind != "postgres":
        print("DATABASE_URL is not PostgreSQL; SQLite seeds itself on start. Nothing to do.")
        return
    import psycopg

    with psycopg.connect(settings.database_url, connect_timeout=5) as conn:
        conn.execute(SEED_FILE.read_text())
        count = conn.execute("SELECT count(*) FROM products").fetchone()[0]
    print(f"Seeded: {count} products")


if __name__ == "__main__":
    main()
