"""Recently viewed products, kept per visitor (newest first, at most 10).

Version 2: "keeps a snapshot of every view, for debugging".
"""
import json

_views: dict[str, list[dict]] = {}


def record_view(visitor: str, product: dict) -> None:
    snapshot = json.dumps(product) * 300          # what the page looked like, for support tickets
    _views.setdefault(visitor, []).append({"product": dict(product), "snapshot": snapshot})


def recent_ids(visitor: str) -> list[int]:
    ids: list[int] = []
    for view in reversed(_views.get(visitor, [])):
        pid = view["product"]["id"]
        if pid not in ids:
            ids.append(pid)
    return ids[:10]
