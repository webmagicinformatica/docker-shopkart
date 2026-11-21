"""A tiny load generator (standard library only).

    python3 labs/production/load.py --requests 2000 --concurrency 20

Each request views a product as a different visitor, like real shoppers browsing.
"""
import argparse
import random
import statistics
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor


def one(url: str, i: int) -> tuple[float, bool]:
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(f"{url}/api/products/{random.randint(1, 8)}?visitor=v{i}", timeout=10) as r:
            r.read()
            ok = r.status == 200
    except Exception:
        ok = False
    return time.perf_counter() - start, ok


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--url", default="http://localhost:8080")
    p.add_argument("--requests", type=int, default=1000)
    p.add_argument("--concurrency", type=int, default=20)
    args = p.parse_args()

    start = time.perf_counter()
    with ThreadPoolExecutor(args.concurrency) as pool:
        results = list(pool.map(lambda i: one(args.url, i), range(args.requests)))
    took = time.perf_counter() - start

    times = sorted(t for t, _ in results)
    errors = sum(1 for _, ok in results if not ok)
    p95 = times[int(len(times) * 0.95) - 1]
    print(f"{args.requests} requests in {took:.1f}s  ({args.requests / took:.0f} req/s)")
    print(f"latency  p50 {statistics.median(times) * 1000:.0f} ms   p95 {p95 * 1000:.0f} ms")
    print(f"errors   {errors}")


if __name__ == "__main__":
    main()
