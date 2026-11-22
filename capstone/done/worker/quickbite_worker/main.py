"""Entry point: connect to Redis and PostgreSQL, then cook orders until stopped.

    python -m quickbite_worker.main
"""
import logging
import signal
import time

import psycopg
import redis

from .config import load_config
from .kitchen import run_once


class PgOrders:
    def __init__(self, pg: dict):
        self.pg = pg
        self.conn = None

    def set_status(self, order_id: int, status: str) -> bool:
        if self.conn is None or self.conn.closed:
            self.conn = psycopg.connect(**self.pg, autocommit=True, connect_timeout=3)
        cur = self.conn.execute(
            "UPDATE orders SET status = %s, updated_at = now() WHERE id = %s", (status, order_id)
        )
        return cur.rowcount == 1


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    log = logging.getLogger("quickbite.worker")
    config = load_config()
    queue = redis.Redis.from_url(config.redis_url, socket_connect_timeout=3, socket_timeout=10)
    orders = PgOrders(config.pg)

    # docker stop sends SIGTERM: finish the current order, then exit 0.
    running = True

    def stop(signum, _frame):
        nonlocal running
        log.info("signal %s received, stopping after the current order", signum)
        running = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    log.info("worker started, kitchen time %ss", config.kitchen_seconds)
    while running:
        try:
            run_once(queue, orders, config)
        except (redis.RedisError, psycopg.Error) as err:
            # No heartbeat while we can't reach Redis or PostgreSQL: the health check notices.
            log.error("backend error: %s; retrying in 2s", err)
            orders.conn = None
            time.sleep(2)
    log.info("worker stopped")


if __name__ == "__main__":
    main()
