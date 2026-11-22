"""The kitchen logic, kept free of Redis and PostgreSQL so it is easy to test."""
import logging
import time
from pathlib import Path

QUEUE_KEY = "quickbite:orders"
log = logging.getLogger("quickbite.worker")


def cook(order_id: int, orders, seconds: float, sleep=time.sleep) -> bool:
    """Move one order from received -> preparing -> ready. False if it doesn't exist."""
    if not orders.set_status(order_id, "preparing"):
        log.warning("order %s not found, skipping", order_id)
        return False
    log.info("order %s preparing", order_id)
    sleep(seconds)
    orders.set_status(order_id, "ready")
    log.info("order %s ready", order_id)
    return True


def beat(path: str) -> None:
    """Record that the worker is alive (the container's health check reads this)."""
    Path(path).touch()


def run_once(queue, orders, config, sleep=time.sleep) -> bool:
    """Wait up to 5 s for one order and cook it. True if an order was handled."""
    beat(config.heartbeat_file)
    item = queue.blpop([QUEUE_KEY], timeout=5)
    if item is None:
        return False
    _, raw = item
    cook(int(raw), orders, config.kitchen_seconds, sleep)
    beat(config.heartbeat_file)
    return True
