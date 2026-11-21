from fastapi.testclient import TestClient

from shopkart_api.main import app

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok", "db": "ok", "cart": "ok"}


def test_products_are_seeded():
    products = client.get("/api/products").json()
    assert len(products) == 8
    assert products[0]["name"] == "Cotton Kurta"


def test_unknown_product_is_404():
    assert client.get("/api/products/999").status_code == 404


def test_cart_total():
    client.delete("/api/cart/t1")
    client.post("/api/cart/t1/items", json={"product_id": 2, "qty": 1})
    cart = client.post("/api/cart/t1/items", json={"product_id": 5, "qty": 2}).json()
    assert cart["total_inr"] == 2499 + 2 * 299
    assert [i["product_id"] for i in cart["items"]] == [2, 5]


def test_cart_rejects_bad_qty():
    assert client.post("/api/cart/t2/items", json={"product_id": 1, "qty": 0}).status_code == 422


def test_recently_viewed_is_bounded():
    for pid in [1, 2, 3, 1]:
        client.get(f"/api/products/{pid}", params={"visitor": "v1"})
    assert client.get("/api/recent/v1").json()["product_ids"] == [1, 3, 2]
    for _ in range(3):
        for pid in range(1, 9):
            client.get(f"/api/products/{pid}", params={"visitor": "v2"})
    assert len(client.get("/api/recent/v2").json()["product_ids"]) == 8


def test_info():
    body = client.get("/api/info").json()
    assert body["app"] == "shopkart-api"
    assert body["db"] == "sqlite"


def test_database_down_is_503(monkeypatch):
    import psycopg

    from shopkart_api import main

    def boom():
        raise psycopg.OperationalError("connection refused")

    monkeypatch.setattr(main.store, "list_products", boom)
    r = client.get("/api/products")
    assert r.status_code == 503
    assert r.json() == {"detail": "A backing service is unavailable"}


def test_seed_is_a_no_op_on_sqlite(capsys):
    from shopkart_api import seed

    seed.main()
    assert "Nothing to do" in capsys.readouterr().out
