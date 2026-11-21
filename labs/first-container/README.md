# Lab: Your first container

Open the course codespace, check Docker, run `hello-world`, then run nginx and open it in the browser.
Before any of that, run ShopKart the old way, straight on Python, so you can see what containers will replace.

Work in `start/commands.sh` (fill in the TODOs). The answers are in `done/commands.sh`.

## 1. Open the codespace

On your copy of the repo: **Code** → **Codespaces** → **Create codespace on main**. Docker is already installed inside it.

## 2. Before containers: run ShopKart on Python

```bash
./scripts/run-local.sh
```

Open port **8000** from the **Ports** tab (or the pop-up). You'll see the shop. It works because the codespace happens to have the right Python and the right libraries.
It is using SQLite and an in-memory cart here, not PostgreSQL and Redis. That's the "works on my machine" problem in one picture. Press **Ctrl+C** to stop it.

## 3. Check Docker

```bash
docker version
```

Two parts: the **Client** (the `docker` command you type) and the **Server** (Docker Engine, which does the work).

## 4. Hello, world

```bash
docker run hello-world
```

Docker didn't have the image, so it **pulled** it from Docker Hub, created a container, ran it, and the container exited.

## 5. Run a web server

```bash
docker run -d --name web -p 8080:80 nginx:1.30.7-alpine
docker ps
curl -s localhost:8080 | head -n 4
```

- `-d` runs it in the background, `--name web` gives it a name, `-p 8080:80` sends port 8080 of the codespace to port 80 inside the container.
- Open port **8080** from the **Ports** tab: "Welcome to nginx!"

## 6. Logs, stop, remove

```bash
docker logs web
docker stop web
docker rm web
docker ps -a
```

## Checkpoint

- [ ] ShopKart ran on Python, without Docker
- [ ] `docker version` shows a Client and a Server
- [ ] You saw "Welcome to nginx!" in the browser
- [ ] `docker ps -a` no longer lists `web`
