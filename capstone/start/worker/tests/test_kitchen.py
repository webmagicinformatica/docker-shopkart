"""Worker tests: fake queue and fake database, so no Redis or PostgreSQL needed."""
import os

import pytest

from quickbite_worker.config import load_config
from quickbite_worker.kitchen import QUEUE_KEY, cook, run_once


class FakeOrders:
    def __init__(self, ids):
        self.status = {i: "received" for i in ids}
        self.history = []

    def set_status(self, order_id, status):
        if order_id not in self.status:
            return False
        self.status[order_id] = status
        self.history.append((order_id, status))
        return True


class FakeQueue:
    def __init__(self, items):
        self.items = list(items)

    def blpop(self, keys, timeout):
        assert keys == [QUEUE_KEY]
        return (QUEUE_KEY.encode(), self.items.pop(0)) if self.items else None


@pytest.fixture
def config(tmp_path):
    return load_config({"KITCHEN_SECONDS": "0", "HEARTBEAT_FILE": str(tmp_path / "hb")})


def test_cook_moves_order_to_ready():
    orders = FakeOrders([7])
    assert cook(7, orders, 0, sleep=lambda s: None)
    assert orders.history == [(7, "preparing"), (7, "ready")]


def test_cook_skips_unknown_order():
    assert not cook(99, FakeOrders([1]), 0, sleep=lambda s: None)


def test_run_once_handles_one_order_and_beats(config):
    orders = FakeOrders([1, 2])
    queue = FakeQueue([b"2"])
    assert run_once(queue, orders, config, sleep=lambda s: None)
    assert orders.status == {1: "received", 2: "ready"}
    assert os.path.exists(config.heartbeat_file)


def test_run_once_empty_queue(config):
    assert not run_once(FakeQueue([]), FakeOrders([]), config)
    assert os.path.exists(config.heartbeat_file)


def test_password_file_wins(tmp_path):
    pw = tmp_path / "pw"
    pw.write_text("s3cret\n")
    config = load_config({"PGPASSWORD": "plain", "PGPASSWORD_FILE": str(pw)})
    assert config.pg["password"] == "s3cret"
    assert config.kitchen_seconds == 3
