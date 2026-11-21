# Lab: Back up, wipe and restore ShopKart; run a migration

Back up the ShopKart database two ways (a `pg_dump` and a volume tarball), destroy everything, restore it, and then change the schema with a **one-off migration container**.

Files: `start/` (TODOs) and `done/`: `compose.yaml` (API, PostgreSQL and a `migrate` job), `backup.sh`, `migrations/002_add_rating.sql`.
You need the `shopkart-api:1.2` image (`docker build --build-arg APP_VERSION=1.2 -t shopkart-api:1.2 app/api`). Backups go to `backups/`, which Git ignores.

## 1. Start, and add some data worth saving

```bash
docker compose -f labs/data/done/compose.yaml up -d --wait
docker compose -f labs/data/done/compose.yaml exec db psql -U shopkart -c "INSERT INTO products VALUES (9, 'Cricket Bat', 'Sports', 1999, 15);"
curl -s localhost:8000/api/products | python3 -c 'import json,sys; print(len(json.load(sys.stdin)), "products")'
```

## 2. Back up two ways

```bash
cat labs/data/done/backup.sh
./labs/data/done/backup.sh
head -n 5 backups/shopkart.sql
```

| | Logical (`pg_dump`) | Physical (volume tarball) |
| --- | --- | --- |
| Database running? | Yes | Stop it first |
| Works on another PostgreSQL version? | Yes | Same major version only |
| Good for | Everyday backups, moving data | Fast full copies of a volume |

## 3. Disaster: wipe everything

```bash
docker compose -f labs/data/done/compose.yaml down -v
docker volume ls --filter name=shopkart-data
docker compose -f labs/data/done/compose.yaml up -d --wait
curl -s localhost:8000/api/products | python3 -c 'import json,sys; print(len(json.load(sys.stdin)), "products")'
```

The volume is gone; the fresh database has only the 8 seed products. The Cricket Bat is lost.

## 4. Restore from the SQL dump

```bash
docker compose -f labs/data/done/compose.yaml exec -T db psql -q -U shopkart -d shopkart < backups/shopkart.sql
curl -s localhost:8000/api/products/9; echo
```

## 5. Restore the volume tarball (the "new host" way)

Moving to another machine? Copy the tarball there, let Compose create the (empty) volume without starting anything, unpack the tarball into it, then start the stack:

```bash
docker compose -f labs/data/done/compose.yaml down -v
docker compose -f labs/data/done/compose.yaml up --no-start
docker run --rm -v shopkart-data_db-data:/data -v "$PWD/backups:/backup:ro" alpine:3.24.4 tar xzf /backup/db-volume.tar.gz -C /data
docker compose -f labs/data/done/compose.yaml up -d --wait
curl -s localhost:8000/api/products/9; echo
```

PostgreSQL finds a data directory that is already set up, so it skips the seed file and starts with your data.

## 6. A schema migration as a one-off container

```bash
cat labs/data/done/migrations/002_add_rating.sql
docker compose -f labs/data/done/compose.yaml run --rm migrate
curl -s localhost:8000/api/products/2; echo
docker compose -f labs/data/done/compose.yaml run --rm migrate       # safe to run again
```

`migrate` is in the `jobs` profile, so `up` never starts it. `run --rm` starts it once, it applies the files and exits, and the container is removed.
The API shows the new `rating` field without a rebuild, because it returns every column.

## Clean up

```bash
docker compose -f labs/data/done/compose.yaml down -v
rm -rf backups
```

## Checkpoint

- [ ] `backups/` has `shopkart.sql` and `db-volume.tar.gz`
- [ ] After `down -v`, product 9 came back from **both** backups
- [ ] Product 2 has a `rating`, and the migration ran twice without errors
