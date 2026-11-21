"""Recently viewed products, kept per visitor (newest first, at most 10)."""
from collections import OrderedDict, deque

MAX_ITEMS = 10
MAX_VISITORS = 10_000

_views: "OrderedDict[str, deque[int]]" = OrderedDict()


def record_view(visitor: str, product: dict) -> None:
    views = _views.pop(visitor, None) or deque(maxlen=MAX_ITEMS)
    if product["id"] in views:
        views.remove(product["id"])
    views.appendleft(product["id"])
    _views[visitor] = views
    while len(_views) > MAX_VISITORS:
        _views.popitem(last=False)


def recent_ids(visitor: str) -> list[int]:
    return list(_views.get(visitor, []))
