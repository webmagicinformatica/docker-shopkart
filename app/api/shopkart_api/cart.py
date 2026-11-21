"""The cart lives in Redis (or in memory when you run without containers)."""


class MemoryCart:
    def __init__(self):
        self._carts: dict[str, dict[str, int]] = {}

    def add(self, cart_id: str, product_id: int, qty: int) -> None:
        items = self._carts.setdefault(cart_id, {})
        items[str(product_id)] = items.get(str(product_id), 0) + qty

    def items(self, cart_id: str) -> dict[int, int]:
        return {int(k): v for k, v in self._carts.get(cart_id, {}).items()}

    def clear(self, cart_id: str) -> None:
        self._carts.pop(cart_id, None)

    def ping(self) -> None:
        return None


class RedisCart:
    TTL_SECONDS = 7 * 24 * 3600

    def __init__(self, url: str):
        import redis

        self._r = redis.Redis.from_url(url, socket_timeout=3, socket_connect_timeout=3)

    def _key(self, cart_id: str) -> str:
        return f"cart:{cart_id}"

    def add(self, cart_id: str, product_id: int, qty: int) -> None:
        key = self._key(cart_id)
        self._r.hincrby(key, str(product_id), qty)
        self._r.expire(key, self.TTL_SECONDS)

    def items(self, cart_id: str) -> dict[int, int]:
        raw = self._r.hgetall(self._key(cart_id))
        return {int(k): int(v) for k, v in raw.items()}

    def clear(self, cart_id: str) -> None:
        self._r.delete(self._key(cart_id))

    def ping(self) -> None:
        self._r.ping()


def make_cart(url: str):
    return MemoryCart() if url.startswith("memory") else RedisCart(url)
