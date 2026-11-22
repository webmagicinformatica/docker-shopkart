// QuickBite front end: plain JavaScript, talks to the API on the same origin under /api.
const rupees = (n) => `₹${n}`;

async function api(path, options) {
  const res = await fetch(path, options);
  if (!res.ok) throw new Error((await res.json()).error || res.statusText);
  return res.json();
}

async function loadMenu() {
  const menu = await api('/api/menu');
  document.getElementById('menu').innerHTML = menu
    .map(
      (m) => `<li><label><input type="number" min="0" max="20" value="0" data-id="${m.id}">
        ${m.name} <span>${rupees(m.price)}</span></label></li>`,
    )
    .join('');
}

async function loadOrders() {
  const orders = await api('/api/orders?limit=10');
  document.getElementById('orders').innerHTML = orders
    .map(
      (o) => `<tr><td>${o.id}</td><td>${o.customer.replace(/[<>&]/g, '')}</td>
        <td>${rupees(o.total)}</td><td><span class="status ${o.status}">${o.status}</span></td></tr>`,
    )
    .join('');
}

document.getElementById('order').addEventListener('submit', async (event) => {
  event.preventDefault();
  const items = [...document.querySelectorAll('#menu input')]
    .filter((i) => Number(i.value) > 0)
    .map((i) => ({ menu_id: Number(i.dataset.id), qty: Number(i.value) }));
  const message = document.getElementById('message');
  try {
    const order = await api('/api/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ customer: document.getElementById('customer').value, items }),
    });
    message.textContent = `Order #${order.id} placed: ${rupees(order.total)}`;
    document.querySelectorAll('#menu input').forEach((i) => (i.value = 0));
    loadOrders();
  } catch (err) {
    message.textContent = `Could not place the order: ${err.message}`;
  }
});

api('/api/info')
  .then((i) => (document.getElementById('info').textContent = `${i.app} ${i.version} · ${i.env} · served by ${i.host}`))
  .catch(() => {});
loadMenu();
loadOrders();
setInterval(loadOrders, 2000);
