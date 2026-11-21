import os
import sys
from pathlib import Path

# Tests never need PostgreSQL or Redis: SQLite in memory + an in-memory cart.
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["REDIS_URL"] = "memory://"
os.environ.pop("WEB_DIR", None)
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
