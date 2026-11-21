# One image, three environments; find and fix a leaked secret: tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

## 1. Build one image

```console
$ docker build --build-arg APP_VERSION=1.2 -t shopkart-api:1.2 app/api
[... 50 earlier lines of output cut ...]
#14 exporting attestation manifest sha256:0c612e32a35955c2f584b78c3048eeaec53ea13917b843c0eaa8116eb66170a5 0.0s done
#14 exporting manifest list sha256:89b477902538b196d92ee65f43a324870ff6a6d354b10504f35183bf85818191
#14 exporting manifest list sha256:89b477902538b196d92ee65f43a324870ff6a6d354b10504f35183bf85818191 0.0s done
#14 naming to docker.io/library/shopkart-api:1.2 done
#14 unpacking to docker.io/library/shopkart-api:1.2 0.0s done
#14 DONE 0.2s
```

## 2. Run it three ways

```console
$ cat labs/config-secrets/done/env/prod.env
APP_ENV=prod
LOG_LEVEL=warning
SHOP_BANNER=Diwali sale: 20% off footwear
$ docker run -d --name api-dev     -p 8001:8000 --env-file labs/config-secrets/done/env/dev.env     shopkart-api:1.2
2a922df2efb9813bd40c1f2213c12996b42621f73e031b5935818b85e13912ae
$ docker run -d --name api-staging -p 8002:8000 --env-file labs/config-secrets/done/env/staging.env shopkart-api:1.2
f0e07421912804a952a9340786461a9e2ac05cf698dff9a340f962a25984a761
$ docker run -d --name api-prod    -p 8003:8000 --env-file labs/config-secrets/done/env/prod.env    shopkart-api:1.2
31a8ec4e8ce97386aa42945e0b2d4a79bc0b06972a335b87f40137dc9d9908b6
$ for p in 8001 8002 8003; do curl -s localhost:$p/api/info; echo; done
{"app":"shopkart-api","version":"1.2","env":"dev","db":"sqlite","banner":"DEV build: test data only","host":"2a922df2efb9"}
{"app":"shopkart-api","version":"1.2","env":"staging","db":"sqlite","banner":"STAGING: checking the Diwali sale","host":"f0e074219128"}
{"app":"shopkart-api","version":"1.2","env":"prod","db":"sqlite","banner":"Diwali sale: 20% off footwear","host":"31a8ec4e8ce9"}
$ docker ps --filter name=api- --format '{{.Names}}  {{.Image}}'
api-prod  shopkart-api:1.2
api-staging  shopkart-api:1.2
api-dev  shopkart-api:1.2
$ docker logs api-dev 2>&1 | head -n 1; docker logs api-prod 2>&1 | head -n 1
INFO shopkart: ShopKart 1.2 starting (env=dev, db=sqlite)
INFO:     Started server process [1]
$ docker rm -f api-dev api-staging api-prod
api-dev
api-staging
api-prod
```

## 3. A leaky Dockerfile

```console
$ cat labs/config-secrets/done/Dockerfile.leaky
# DON'T DO THIS: a secret passed as a build argument and an environment variable.
# Both end up in the image for anyone who can pull it.
FROM python:3.12.16-alpine3.24
ARG PIP_INDEX_TOKEN
# "Our private package index needs a token to install dependencies"
ENV PAYMENT_API_KEY=pk_live_shopkart_51NdemoKEYdoNotUse
WORKDIR /app
COPY requirements.txt .
RUN echo "authenticating to the private index with ${PIP_INDEX_TOKEN}" > /dev/null \
 && pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
$ docker build --build-arg PIP_INDEX_TOKEN=pit_live_7Hq2demoTOKEN -f labs/config-secrets/done/Dockerfile.leaky -t shopkart-api:leaky app/api
[... 107 earlier lines of output cut ...]

 2 warnings found (use docker --debug to expand):
 - SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data (ARG "PIP_INDEX_TOKEN") (line 4)
 - SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data (ENV "PAYMENT_API_KEY") (line 6)
```

Anyone who can pull the image can read both secrets:

```console
$ docker history --no-trunc --format '{{.CreatedBy}}' shopkart-api:leaky | grep -o 'PIP_INDEX_TOKEN=[^ ]*'
PIP_INDEX_TOKEN=pit_live_7Hq2demoTOKEN
PIP_INDEX_TOKEN=pit_live_7Hq2demoTOKEN
$ docker inspect shopkart-api:leaky --format '{{json .Config.Env}}'
["PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","LANG=C.UTF-8","GPG_KEY=7169605F62C751356D054A26A821E680E5FA6305","PYTHON_VERSION=3.12.16","PYTHON_SHA256=b5796915dc45ff745cfb4e990a7e7c93d6f546328a102ce31448d69ebc37575c","PAYMENT_API_KEY=pk_live_shopkart_51NdemoKEYdoNotUse"]
```

## 4. Fix it: a build secret, and no secrets in ENV

```console
$ cat labs/config-secrets/done/Dockerfile.fixed
# syntax=docker/dockerfile:1
# The fix: the build secret is mounted for ONE step and never stored in a layer.
# Runtime secrets (the payment key) come from the environment or a secrets file at run time.
FROM python:3.12.16-alpine3.24
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=secret,id=pip_index_token,env=PIP_INDEX_TOKEN \
    test -n "$PIP_INDEX_TOKEN" && echo "token is available during this step only" \
 && pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
$ export PIP_INDEX_TOKEN=pit_live_7Hq2demoTOKEN; docker build --secret id=pip_index_token,env=PIP_INDEX_TOKEN -f labs/config-secrets/done/Dockerfile.fixed -t shopkart-api:fixed app/api 2>&1 | grep -E 'token is available|naming to'
#10 [stage-0 4/5] RUN --mount=type=secret,id=pip_index_token,env=PIP_INDEX_TOKEN     test -n "****" && echo "token is available during this step only"  && pip install --no-cache-dir -r requirements.txt
#10 0.237 token is available during this step only
#12 naming to docker.io/library/shopkart-api:fixed done
$ docker history --no-trunc --format '{{.CreatedBy}}' shopkart-api:fixed | grep -c pit_live || true
0
$ docker inspect shopkart-api:fixed --format '{{json .Config.Env}}'
["PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","LANG=C.UTF-8","GPG_KEY=7169605F62C751356D054A26A821E680E5FA6305","PYTHON_VERSION=3.12.16","PYTHON_SHA256=b5796915dc45ff745cfb4e990a7e7c93d6f546328a102ce31448d69ebc37575c"]
```

## 5. Runtime secrets with Compose

```console
$ mkdir -p labs/config-secrets/done/secrets && python3 -c 'import secrets; print(secrets.token_urlsafe(18))' > labs/config-secrets/done/secrets/db_password.txt
$ git status --short --ignored labs/config-secrets/done
?? labs/config-secrets/done/
!! labs/config-secrets/done/secrets/
$ SHOPKART_ENV=staging docker compose -f labs/config-secrets/done/compose.yaml up -d --build --wait 2>&1 | tail -n 4
 Container shopkart-config-db-1  Waiting
 Container shopkart-config-redis-1  Healthy
 Container shopkart-config-db-1  Healthy
 Container shopkart-config-api-1  Healthy
$ curl -s localhost:8000/api/info; echo
{"app":"shopkart-api","version":"dev","env":"staging","db":"postgres","banner":"STAGING: checking the Diwali sale","host":"ebbcb329b8a7"}
$ docker compose -f labs/config-secrets/done/compose.yaml exec api sh -c 'env | grep -E "^(APP_ENV|DATABASE)" ; ls -l /run/secrets'
DATABASE_URL=postgresql://shopkart@db:5432/shopkart
DATABASE_PASSWORD_FILE=/run/secrets/db_password
APP_ENV=staging
total 4
-rw-r--r--    1 1000     1000            25 Nov 21 20:05 db_password
$ docker inspect shopkart-config-api-1 --format '{{json .Config.Env}}' | tr ',' '\n' | grep -i -E 'pass|database'
["DATABASE_PASSWORD_FILE=/run/secrets/db_password"
"DATABASE_URL=postgresql://shopkart@db:5432/shopkart"
```

Same image, switch to prod:

```console
$ SHOPKART_ENV=prod docker compose -f labs/config-secrets/done/compose.yaml up -d --wait 2>&1 | tail -n 2
 Container shopkart-config-redis-1  Healthy
 Container shopkart-config-api-1  Healthy
$ curl -s localhost:8000/api/info; echo
{"app":"shopkart-api","version":"dev","env":"prod","db":"postgres","banner":"Diwali sale: 20% off footwear","host":"7a467ed444c6"}
```

## Clean up

```console
$ docker compose -f labs/config-secrets/done/compose.yaml down -v 2>&1 | tail -n 3
 Network shopkart-config_default  Removing
 Volume shopkart-config_db-data  Removed
 Network shopkart-config_default  Removed
$ docker rmi shopkart-api:leaky shopkart-api:fixed
Untagged: shopkart-api:leaky
Deleted: sha256:8434528dc91d5c44a90075d6d1dfe2c393d3987ee61ed917a3ebe64788be49a5
Untagged: shopkart-api:fixed
Deleted: sha256:9d5322fedc29d6b82a5925561785a82ece1163aceceb8eb9bdaa0e449446f7b4
```

