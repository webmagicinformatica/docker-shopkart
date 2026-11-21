"""ShopKart API: products, a cart and a health check. Small and boring on purpose."""
import logging
import os
import socket

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import recent
from .cart import make_cart
from .config import load_settings
from .db import ProductStore

settings = load_settings()
logging.basicConfig(level=settings.log_level.upper(), format="%(levelname)s %(name)s: %(message)s")
log = logging.getLogger("shopkart")

app = FastAPI(title="ShopKart API", version=settings.version)
store = ProductStore(settings.database_url)
cart = make_cart(settings.redis_url)
log.info("ShopKart %s starting (env=%s, db=%s)", settings.version, settings.app_env, store.kind)


def _is_dependency_error(exc: Exception) -> bool:
    name = type(exc).__module__ + "." + type(exc).__name__
    return name.startswith(("psycopg.", "redis.exceptions."))


@app.middleware("http")
async def dependency_errors(request: Request, call_next):
    """PostgreSQL or Redis unreachable: answer 503 instead of a bare 500."""
    try:
        return await call_next(request)
    except Exception as exc:
        if _is_dependency_error(exc):
            log.error("dependency unavailable on %s: %s", request.url.path, type(exc).__name__)
            return JSONResponse(status_code=503, content={"detail": "A backing service is unavailable"})
        raise


class CartItem(BaseModel):
    product_id: int
    qty: int = Field(default=1, ge=1, le=20)


@app.get("/health")
@app.get("/api/health")
def health():
    checks = {}
    for name, dep in (("db", store), ("cart", cart)):
        try:
            dep.ping()
            checks[name] = "ok"
        except Exception as exc:  # report, don't crash
            checks[name] = f"error: {type(exc).__name__}"
    ok = all(v == "ok" for v in checks.values())
    if not ok:
        raise HTTPException(status_code=503, detail={"status": "down", **checks})
    return {"status": "ok", **checks}


@app.get("/api/info")
def info():
    return {
        "app": "shopkart-api",
        "version": settings.version,
        "env": settings.app_env,
        "db": store.kind,
        "banner": settings.banner,
        "host": socket.gethostname(),
    }


@app.get("/api/products")
def list_products():
    return store.list_products()


@app.get("/api/products/{product_id}")
def get_product(product_id: int, visitor: str = "anonymous"):
    product = store.get_product(product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    recent.record_view(visitor, product)
    return product


@app.get("/api/recent/{visitor}")
def recently_viewed(visitor: str):
    return {"visitor": visitor, "product_ids": recent.recent_ids(visitor)}


def _cart_view(cart_id: str) -> dict:
    lines, total = [], 0
    for product_id, qty in sorted(cart.items(cart_id).items()):
        product = store.get_product(product_id)
        if product is None:
            continue
        line_total = product["price_inr"] * qty
        total += line_total
        lines.append({"product_id": product_id, "name": product["name"], "qty": qty,
                      "price_inr": product["price_inr"], "line_total_inr": line_total})
    return {"cart_id": cart_id, "items": lines, "total_inr": total}


@app.get("/api/cart/{cart_id}")
def get_cart(cart_id: str):
    return _cart_view(cart_id)


@app.post("/api/cart/{cart_id}/items", status_code=201)
def add_to_cart(cart_id: str, item: CartItem):
    if store.get_product(item.product_id) is None:
        raise HTTPException(status_code=404, detail="Product not found")
    cart.add(cart_id, item.product_id, item.qty)
    return _cart_view(cart_id)


@app.delete("/api/cart/{cart_id}")
def clear_cart(cart_id: str):
    cart.clear(cart_id)
    return _cart_view(cart_id)


# Running without containers? Serve the front end from the API too (WEB_DIR=app/web).
if settings.web_dir and os.path.isdir(settings.web_dir):
    app.mount("/", StaticFiles(directory=settings.web_dir, html=True), name="web")
