# Lab: One image, three environments; find and fix a leaked secret

1. Build the ShopKart API **once** and run that same image as dev, staging and prod, with settings from env files.
2. Find two secrets leaked into an image (a build argument and an `ENV`), then fix the Dockerfile with a **build secret**.
3. Give the database password to PostgreSQL and the API as a **Compose secret** (a file), never as plain environment.

Files: `start/` (TODOs) and `done/`: `env/*.env`, `Dockerfile.leaky`, `Dockerfile.fixed`, `compose.yaml`.

## 1. Build one image

```bash
docker build --build-arg APP_VERSION=1.2 -t shopkart-api:1.2 app/api
```

## 2. Run it three ways

```bash
cat labs/config-secrets/done/env/prod.env
docker run -d --name api-dev     -p 8001:8000 --env-file labs/config-secrets/done/env/dev.env     shopkart-api:1.2
docker run -d --name api-staging -p 8002:8000 --env-file labs/config-secrets/done/env/staging.env shopkart-api:1.2
docker run -d --name api-prod    -p 8003:8000 --env-file labs/config-secrets/done/env/prod.env    shopkart-api:1.2
for p in 8001 8002 8003; do curl -s localhost:$p/api/info; echo; done
docker ps --filter name=api- --format '{{.Names}}  {{.Image}}'
docker logs api-dev 2>&1 | head -n 1; docker logs api-prod 2>&1 | head -n 1
docker rm -f api-dev api-staging api-prod
```

Same image, three behaviours (banner, `env`, log level: prod at `warning` doesn't print the INFO start line). Config lives in the environment, not in the image.

## 3. A leaky Dockerfile

```bash
cat labs/config-secrets/done/Dockerfile.leaky
docker build --build-arg PIP_INDEX_TOKEN=pit_live_7Hq2demoTOKEN -f labs/config-secrets/done/Dockerfile.leaky -t shopkart-api:leaky app/api
docker history --no-trunc --format '{{.CreatedBy}}' shopkart-api:leaky | grep -o 'PIP_INDEX_TOKEN=[^ ]*'
docker inspect shopkart-api:leaky --format '{{json .Config.Env}}' | tr ',' '\n' | grep -E 'KEY|TOKEN'
```

Docker even warns you during the build (`SecretsUsedInArgOrEnv`). A build argument used in a `RUN` is saved in the image history, and an `ENV` is saved in the image config. Deleting it in a later layer doesn't help: the old layer still has it.
If a real secret ever got pushed like this: **rotate it** (make a new one, revoke the old one). Rebuilding isn't enough.

## 4. Fix it with a build secret

```bash
cat labs/config-secrets/done/Dockerfile.fixed
export PIP_INDEX_TOKEN=pit_live_7Hq2demoTOKEN
docker build --secret id=pip_index_token,env=PIP_INDEX_TOKEN -f labs/config-secrets/done/Dockerfile.fixed -t shopkart-api:fixed app/api
docker history --no-trunc --format '{{.CreatedBy}}' shopkart-api:fixed | grep -c pit_live
docker inspect shopkart-api:fixed --format '{{json .Config.Env}}' | tr ',' '\n' | grep -E 'KEY|TOKEN' || echo 'no secrets in Env'
```

`RUN --mount=type=secret` makes the token available to that one step only. It's never written to a layer, and the build log shows `****`.

## 5. Runtime secrets with Compose

Create the password file (it's git-ignored, check with `git status --ignored`):

```bash
mkdir -p labs/config-secrets/done/secrets
python3 -c 'import secrets; print(secrets.token_urlsafe(18))' > labs/config-secrets/done/secrets/db_password.txt
git status --short --ignored labs/config-secrets/done
```

Start the stack as staging, then look at what the API can see:

```bash
SHOPKART_ENV=staging docker compose -f labs/config-secrets/done/compose.yaml up -d --wait
curl -s localhost:8000/api/info; echo
docker compose -f labs/config-secrets/done/compose.yaml exec api sh -c 'env | grep -E "^(APP_ENV|DATABASE)" ; ls -l /run/secrets'
docker inspect shopkart-config-api-1 --format '{{json .Config.Env}}' | tr ',' '\n' | grep -i -E 'pass|database'
```

The password is a file at `/run/secrets/db_password`. PostgreSQL reads it through `POSTGRES_PASSWORD_FILE`, the API through `DATABASE_PASSWORD_FILE`. It is not in `docker inspect`, not in the env, and not in Git.

Same image, now as prod:

```bash
SHOPKART_ENV=prod docker compose -f labs/config-secrets/done/compose.yaml up -d --wait
curl -s localhost:8000/api/info; echo
```

## Clean up

```bash
docker compose -f labs/config-secrets/done/compose.yaml down -v
docker rmi shopkart-api:leaky shopkart-api:fixed
```

## Checkpoint

- [ ] Three containers from one image showed three different banners
- [ ] You found the token in `docker history` and the key in `docker inspect` of the leaky image
- [ ] Neither appears in the fixed image
- [ ] The database password exists only in `secrets/db_password.txt` (ignored by Git) and `/run/secrets`
