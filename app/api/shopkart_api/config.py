"""Settings come from environment variables (twelve-factor style).

With nothing set, ShopKart runs on your laptop with SQLite and an in-memory cart.
In containers, set DATABASE_URL and REDIS_URL to PostgreSQL and Redis.
"""
import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote, urlsplit, urlunsplit


def _read_secret(name: str) -> str | None:
    """Return the value of NAME, or the contents of the file named in NAME_FILE."""
    path = os.getenv(f"{name}_FILE")
    if path:
        return Path(path).read_text().strip()
    return os.getenv(name)


def _with_password(url: str, password: str | None) -> str:
    if not password or not url.startswith("postgres"):
        return url
    parts = urlsplit(url)
    user = parts.username or "shopkart"
    host = parts.hostname or "localhost"
    netloc = f"{user}:{quote(password, safe='')}@{host}"
    if parts.port:
        netloc += f":{parts.port}"
    return urlunsplit(parts._replace(netloc=netloc))


@dataclass(frozen=True)
class Settings:
    app_env: str
    version: str
    log_level: str
    database_url: str
    redis_url: str
    banner: str
    web_dir: str | None

    @property
    def db_kind(self) -> str:
        return "postgres" if self.database_url.startswith("postgres") else "sqlite"


def load_settings() -> Settings:
    database_url = os.getenv("DATABASE_URL", "sqlite:///:memory:")
    return Settings(
        app_env=os.getenv("APP_ENV", "local"),
        version=os.getenv("APP_VERSION", "dev"),
        log_level=os.getenv("LOG_LEVEL", "info"),
        database_url=_with_password(database_url, _read_secret("DATABASE_PASSWORD")),
        redis_url=os.getenv("REDIS_URL", "memory://"),
        banner=os.getenv("SHOP_BANNER", ""),
        web_dir=os.getenv("WEB_DIR"),
    )
