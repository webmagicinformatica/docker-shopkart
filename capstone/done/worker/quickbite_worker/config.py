"""All configuration comes from environment variables (twelve-factor)."""
import os
from dataclasses import dataclass


@dataclass
class Config:
    redis_url: str
    pg: dict
    kitchen_seconds: float
    heartbeat_file: str


def load_config(env=os.environ) -> Config:
    # The password can come from PGPASSWORD or, better, from a file (PGPASSWORD_FILE),
    # which is how Docker and Compose secrets hand it over.
    password = env.get("PGPASSWORD")
    if env.get("PGPASSWORD_FILE"):
        with open(env["PGPASSWORD_FILE"], encoding="utf-8") as f:
            password = f.read().strip()
    return Config(
        redis_url=env.get("REDIS_URL", "redis://localhost:6379/0"),
        pg={
            "host": env.get("PGHOST", "localhost"),
            "port": int(env.get("PGPORT", "5432")),
            "user": env.get("PGUSER", "quickbite"),
            "dbname": env.get("PGDATABASE", "quickbite"),
            "password": password,
        },
        kitchen_seconds=float(env.get("KITCHEN_SECONDS", "3")),
        # Touched on every loop: if it goes stale, the worker is stuck.
        heartbeat_file=env.get("HEARTBEAT_FILE", "/tmp/quickbite-worker.heartbeat"),
    )
