// ShopKart front end: plain JavaScript, talks to the API under /api.
const API = "/api";
const cartId = localStorage.getItem("shopkart-cart") || crypto.randomUUID().slice(0, 8);
localStorage.setItem("shopkart-cart", cartId);
const rupees = (n) => "₹" + n.toLocaleString("en-IN");

async function call(path, options) {
  const res = await fetch(API + path, options);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json();
}

function showCart(cart) {
  const list = document.getElementById("cart");
  list.innerHTML = "";
  for (const item of cart.items) {
    const li = document.createElement("li");
    li.textContent = `${item.qty} × ${item.name} — ${rupees(item.line_total_inr)}`;
    list.appendChild(li);
  }
  if (!cart.items.length) list.innerHTML = "<li class=muted>Empty</li>";
  document.getElementById("total").textContent = rupees(cart.total_inr);
}

async function load() {
  const status = document.getElementById("status");
  try {
    const [products, info, cart] = await Promise.all([
      call("/products"), call("/info"), call(`/cart/${cartId}`),
    ]);
    status.textContent = `${products.length} products · served by ${info.host}`;
    document.getElementById("info").textContent =
      `shopkart-api ${info.version} · env ${info.env} · database ${info.db}`;
    if (info.banner) {
      const banner = document.getElementById("banner");
      banner.textContent = info.banner;
      banner.hidden = false;
    }
    const grid = document.getElementById("products");
    grid.innerHTML = "";
    for (const p of products) {
      const li = document.createElement("li");
      li.innerHTML = `<h3></h3><p class="muted"></p><p class="price"></p><button type="button">Add to cart</button>`;
      li.querySelector("h3").textContent = p.name;
      li.querySelector(".muted").textContent = p.category;
      li.querySelector(".price").textContent = rupees(p.price_inr);
      li.querySelector("button").onclick = async () => showCart(await call(`/cart/${cartId}/items`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ product_id: p.id, qty: 1 }),
      }));
      grid.appendChild(li);
    }
    showCart(cart);
  } catch (err) {
    status.textContent = `Can't reach the API (${err.message})`;
    status.classList.add("error");
  }
}

document.getElementById("clear").onclick = async () =>
  showCart(await call(`/cart/${cartId}`, { method: "DELETE" }));
load();
