#!/usr/bin/env bash
# QuickBite capstone: acceptance checks. Prints PASS or FAIL for every requirement in BRIEF.md.
#
#   ./capstone/check.sh                  # checks capstone/start (your work)
#   ./capstone/check.sh capstone/done    # checks the reference solution
#   SKIP_SCAN=1 ./capstone/check.sh      # skip the Trivy scan (slow the first time)
#
# It builds your images, starts the stack under its own project name (qbcheck), places an order,
# restarts the stack, inspects the running containers, tries compose watch, scans the images,
# and reads your pipeline. At the end it removes the qbcheck containers, networks and volumes.
# Needs: Docker with Compose v2.24+, curl, python3, git.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIR=$(cd "${1:-$ROOT/capstone/start}" 2>/dev/null && pwd) || { echo "No such folder: ${1:-}"; exit 2; }
PROJECT=qbcheck
TRIVY_IMAGE=aquasec/trivy:0.76.2
SERVICES="web api worker db redis"
APP_SERVICES="api worker web"
TMP=$(mktemp -d)
export WEB_PORT=${WEB_PORT:-18080} DB_PORT=${DB_PORT:-15432}   # in case your compose files use them

PASSES=0; FAILS=0; N=0
pass() { N=$((N+1)); PASSES=$((PASSES+1)); printf '%2d  PASS  %s\n' "$N" "$1"; }
fail() { N=$((N+1)); FAILS=$((FAILS+1)); printf '%2d  FAIL  %s\n' "$N" "$1"; [ -n "${2:-}" ] && printf '          -> %s\n' "$2"; }
result() { if [ "$1" = 0 ]; then pass "$2"; else fail "$2" "${3:-}"; fi; }

cd "$DIR" || exit 2
compose() { docker compose -p "$PROJECT" -f compose.yaml "$@"; }
HAVE_COMPOSE=0; [ -f compose.yaml ] && HAVE_COMPOSE=1
STACK_UP=0

cleanup() {
  [ -n "${WATCH_PID:-}" ] && kill "$WATCH_PID" 2>/dev/null
  [ -n "${WATCH_FILE:-}" ] && [ -f "$TMP/watch.bak" ] && cp "$TMP/watch.bak" "$WATCH_FILE"
  if [ "$HAVE_COMPOSE" = 1 ]; then
    docker compose -p "$PROJECT" -f compose.yaml ${DEV_FILE:+-f "$DEV_FILE"} down -v --remove-orphans >/dev/null 2>&1
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "QuickBite capstone check: ${DIR#"$ROOT"/}"
echo "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null), Compose $(docker compose version --short 2>/dev/null)"
echo

# The secret file is git-ignored, so a fresh clone doesn't have it: make a random one.
if [ "$HAVE_COMPOSE" = 1 ]; then
  for f in $(docker compose -f compose.yaml config --format json 2>/dev/null \
      | python3 -c 'import json,sys; [print(s["file"]) for s in json.load(sys.stdin).get("secrets", {}).values() if "file" in s]' 2>/dev/null); do
    if [ ! -f "$f" ]; then
      mkdir -p "$(dirname "$f")" && openssl rand -hex 16 > "$f" && echo "(created a random $f for this check)"
    fi
  done
  docker compose -f compose.yaml config --format json > "$TMP/config.json" 2>"$TMP/config.err" || true
fi

# A small helper that answers questions about the merged Compose config.
cfg() { python3 - "$TMP/config.json" "$@" <<'PY'
import json, sys
path, check = sys.argv[1], sys.argv[2]
try:
    c = json.load(open(path))
except Exception:
    print("compose.yaml does not parse"); sys.exit(1)
svcs = c.get("services", {})
need = ["web", "api", "worker", "db", "redis"]
problems = []
if check == "services":
    missing = [s for s in need if s not in svcs]
    if missing: problems.append("missing services: " + ", ".join(missing))
elif check == "healthgated":
    for s in need:
        if s not in svcs: continue
        hc = svcs[s].get("healthcheck")
        if hc and hc.get("disable"): problems.append(f"{s}: healthcheck disabled")
        for dep, d in (svcs[s].get("depends_on") or {}).items():
            if d.get("condition") != "service_healthy":
                problems.append(f"{s} -> {dep} is not condition: service_healthy")
    wants = {"api": ["db", "redis"], "worker": ["db", "redis"], "web": ["api"]}
    for s, deps in wants.items():
        for d in deps:
            if d not in (svcs.get(s, {}).get("depends_on") or {}):
                problems.append(f"{s} does not depend on {d}")
elif check == "volumes":
    want = {"db": "/var/lib/postgresql/data", "redis": "/data"}
    for s, target in want.items():
        vols = svcs.get(s, {}).get("volumes") or []
        if not any(v.get("type") == "volume" and v.get("target") == target and v.get("source") for v in vols):
            problems.append(f"{s}: {target} is not a named volume")
elif check == "networks":
    for s in ["api", "worker", "db", "redis"]:
        if svcs.get(s, {}).get("ports"): problems.append(f"{s} publishes a port (only web should)")
    if not svcs.get("web", {}).get("ports"): problems.append("web publishes no port")
    web_nets = set((svcs.get("web", {}).get("networks") or {"default": None}).keys())
    for s in ["db", "redis"]:
        nets = set((svcs.get(s, {}).get("networks") or {"default": None}).keys())
        if nets & web_nets: problems.append(f"web and {s} share a network: {', '.join(sorted(nets & web_nets))}")
elif check == "secrets":
    if not c.get("secrets"): problems.append("no top-level secrets:")
    for s in ["db", "api", "worker"]:
        if not svcs.get(s, {}).get("secrets"): problems.append(f"{s} gets no secret")
        for k, v in (svcs.get(s, {}).get("environment") or {}).items():
            if "PASSWORD" in k.upper() and not k.upper().endswith("_FILE"):
                problems.append(f"{s}: {k} is set in the environment")
    print("\n".join(x.get("file", "") for x in c.get("secrets", {}).values() if x.get("file")), file=open(path + ".secretfiles", "w"))
elif check == "watch":
    for s in ["api", "worker", "web"]:
        if not (svcs.get(s, {}).get("develop") or {}).get("watch"):
            problems.append(f"{s} has no develop.watch")
if problems:
    print("; ".join(problems)); sys.exit(1)
PY
}

# ---------------------------------------------------------------- images
missing=""
for s in $APP_SERVICES; do
  [ -f "$s/Dockerfile" ] || missing="$missing $s/Dockerfile"
  [ -f "$s/.dockerignore" ] || [ -f "$s/Dockerfile.dockerignore" ] || missing="$missing $s/.dockerignore"
done
[ -z "$missing" ]; result $? "Dockerfiles: api, worker and web each have a Dockerfile and a .dockerignore" "missing:$missing"

msg=""
for s in api worker; do
  [ -f "$s/Dockerfile" ] || { msg="$msg $s: no Dockerfile;"; continue; }
  stages=$(grep -ciE '^\s*FROM\s' "$s/Dockerfile")
  [ "$stages" -ge 2 ] || msg="$msg $s has $stages stage(s);"
  grep -qiE '^\s*FROM\s.+\sAS\s+test\s*$' "$s/Dockerfile" || msg="$msg $s has no 'test' stage;"
  grep -qiE '^\s*FROM\s.+\sAS\s+runtime\s*$' "$s/Dockerfile" || msg="$msg $s has no 'runtime' stage;"
done
[ -z "$msg" ]; result $? "Multi-stage: api and worker have test and runtime stages" "$msg"

msg=""
for s in api worker; do
  if [ -f "$s/Dockerfile" ]; then
    docker build -q --target test -t "qbcheck-$s-test" "$s" > "$TMP/test-$s.log" 2>&1 || msg="$msg $s tests failed (docker build --target test $s);"
    docker image rm "qbcheck-$s-test" >/dev/null 2>&1
  else
    msg="$msg $s: no Dockerfile;"
  fi
done
[ -z "$msg" ]; result $? "Tests run in the build: docker build --target test passes for api and worker" "$msg"

BUILT=0
if [ "$HAVE_COMPOSE" = 1 ] && compose build > "$TMP/build.log" 2>&1; then BUILT=1; fi
[ "$BUILT" = 1 ]; result $? "Build: docker compose build succeeds" "$([ "$HAVE_COMPOSE" = 1 ] && tail -n 3 "$TMP/build.log" | tr '\n' ' ' || echo 'no compose.yaml')"

# The image each app service uses
img() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["services"][sys.argv[2]].get("image",""))' "$TMP/config.json" "$1" 2>/dev/null; }

msg=""
for s in $APP_SERVICES; do
  [ -f "$s/Dockerfile" ] || { msg="$msg $s: no Dockerfile;"; continue; }
  while read -r ref; do
    case "$ref" in
      *@sha256:*) ;;
      *:latest|*:latest-*) msg="$msg $s: $ref uses latest;" ;;
      *:*[0-9]*.*[0-9]*) ;;
      *) msg="$msg $s: $ref has no version;" ;;
    esac
  done < <(awk 'toupper($1)=="FROM"{for(i=2;i<=NF;i++) if ($i !~ /^--/) {print $i; break}}' "$s/Dockerfile" | grep -vxE "$(awk 'toupper($1)=="FROM" && toupper($(NF-1))=="AS"{print $NF}' "$s/Dockerfile" | paste -sd'|' -)" )
done
if [ "$HAVE_COMPOSE" = 1 ]; then
  for s in db redis; do
    ref=$(img $s)
    case "$ref" in *:*[0-9]*.*[0-9]*|*@sha256:*) ;; *) msg="$msg $s: '$ref' is not pinned to a version;" ;; esac
  done
else
  msg="$msg no compose.yaml;"
fi
[ -z "$msg" ]; result $? "Pinned: every base image and service image has an exact version (no latest)" "$msg"

LIMITS="api:300 worker:200 web:150"; SIZES=""; COUNTS=""
msg=""
for l in $LIMITS; do
  s=${l%%:*}; max=${l##*:}
  ref=$(img "$s")
  size=$(docker image inspect -f '{{.Size}}' "$ref" 2>/dev/null) || { msg="$msg $s: no image;"; continue; }
  mb=$((size / 1000000))
  [ "$mb" -le "$max" ] || msg="$msg $s is ${mb} MB (max $max);"
  SIZES="${SIZES:-}$s ${mb} MB, "
done
[ -z "$msg" ]; result $? "Small images: api <= 300 MB, worker <= 200 MB, web <= 150 MB${SIZES:+ (${SIZES%, })}" "$msg"

msg=""
for s in $APP_SERVICES; do
  ref=$(img "$s"); u=$(docker image inspect -f '{{.Config.User}}' "$ref" 2>/dev/null) || { msg="$msg $s: no image;"; continue; }
  case "${u%%:*}" in ""|root|0) msg="$msg $s runs as '${u:-root}';" ;; esac
done
[ -z "$msg" ]; result $? "Non-root images: api, worker and web set USER to an unprivileged user" "$msg"

msg=""
for s in $APP_SERVICES; do
  ref=$(img "$s"); hc=$(docker image inspect -f '{{if .Config.Healthcheck}}{{.Config.Healthcheck.Test}}{{end}}' "$ref" 2>/dev/null) || { msg="$msg $s: no image;"; continue; }
  [ -n "$hc" ] || msg="$msg $s has no HEALTHCHECK;"
done
[ -z "$msg" ]; result $? "Image healthchecks: api, worker and web have a HEALTHCHECK" "$msg"

# ---------------------------------------------------------------- compose
if [ "$HAVE_COMPOSE" = 1 ]; then out=$(cfg services); r=$?; else out="no compose.yaml"; r=1; fi
result $r "Compose: one compose.yaml with web, api, worker, db and redis" "$out"

if [ "$HAVE_COMPOSE" = 1 ]; then out=$(cfg healthgated); r=$?; else out="no compose.yaml"; r=1; fi
result $r "Health-gated start: every depends_on waits for service_healthy" "$out"

if [ "$HAVE_COMPOSE" = 1 ]; then out=$(cfg volumes); r=$?; else out="no compose.yaml"; r=1; fi
result $r "Named volumes: PostgreSQL and Redis data live in named volumes" "$out"

if [ "$HAVE_COMPOSE" = 1 ]; then out=$(cfg networks); r=$?; else out="no compose.yaml"; r=1; fi
result $r "Networks: only web publishes a port; web can't reach db or redis" "$out"

if [ "$HAVE_COMPOSE" = 1 ]; then
  out=$(cfg secrets); r=$?
  while read -r f; do
    [ -z "$f" ] && continue
    git -C "$DIR" check-ignore -q "$f" || { out="$out; $f is not git-ignored"; r=1; }
    git -C "$DIR" ls-files --error-unmatch "$f" >/dev/null 2>&1 && { out="$out; $f is committed"; r=1; }
  done < "$TMP/config.json.secretfiles"
  # The password must not be baked into any image (history, labels or environment)
  while read -r f; do
    [ -f "$f" ] || continue; pw=$(tr -d '\n' < "$f"); [ -n "$pw" ] || continue
    for s in $APP_SERVICES; do
      ref=$(img "$s"); [ -n "$ref" ] || continue
      { docker history --no-trunc "$ref"; docker image inspect "$ref"; } 2>/dev/null | grep -qF "$pw" && { out="$out; the password is inside $ref"; r=1; }
    done
  done < "$TMP/config.json.secretfiles"
  [ -f .env.example ] || { out="$out; no .env.example"; r=1; }
  git -C "$DIR" ls-files --error-unmatch .env >/dev/null 2>&1 && { out="$out; .env is committed"; r=1; }
else out="no compose.yaml"; r=1; fi
result $r "Secrets and config: DB password is a Compose secret (git-ignored, not in any image), .env.example, no password in env" "${out#; }"

# ---------------------------------------------------------------- the running stack
if [ "$BUILT" = 1 ] && compose up -d --wait --wait-timeout 180 > "$TMP/up.log" 2>&1; then STACK_UP=1; fi
if [ "$STACK_UP" = 1 ]; then
  unhealthy=$(for s in $SERVICES; do c=$(compose ps -q "$s"); [ -n "$c" ] || { echo "$s(missing)"; continue; }
    h=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$c"); [ "$h" = healthy ] || echo "$s($h)"; done)
  [ -z "$unhealthy" ]; result $? "Stack up: docker compose up --wait succeeds and all 5 services are healthy" "not healthy: $unhealthy"
else
  result 1 "Stack up: docker compose up --wait succeeds and all 5 services are healthy" "$( [ -f "$TMP/up.log" ] && tail -n 3 "$TMP/up.log" | tr '\n' ' ' || echo 'not built')"
fi

URL=""
if [ "$STACK_UP" = 1 ]; then
  port=$(compose port web 8080 2>/dev/null | awk -F: '{print $NF}')
  [ -n "$port" ] && URL="http://127.0.0.1:$port"
fi
ORDER_ID=""
if [ -n "$URL" ]; then
  ORDER_ID=$(curl -fsS -X POST "$URL/api/orders" -H 'Content-Type: application/json' \
    -d '{"customer":"Checker","items":[{"menu_id":3,"qty":1},{"menu_id":6,"qty":2}]}' 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' 2>/dev/null)
  status=""; secs=0
  while [ "$secs" -lt 30 ]; do
    status=$(curl -fsS "$URL/api/orders/$ORDER_ID" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' 2>/dev/null)
    [ "$status" = ready ] && break; sleep 1; secs=$((secs+1))
  done
  [ "$status" = ready ]; result $? "End to end: an order placed through web is cooked by the worker (ready after ${secs} s)" "order '${ORDER_ID}' status '${status}' after 30 s"
else
  result 1 "End to end: an order placed through web is cooked by the worker" "stack not running or web publishes no port 8080"
fi

if [ -n "$ORDER_ID" ]; then
  compose down > /dev/null 2>&1
  compose up -d --wait --wait-timeout 180 > /dev/null 2>&1
  port=$(compose port web 8080 2>/dev/null | awk -F: '{print $NF}'); URL="http://127.0.0.1:$port"
  got=$(curl -fsS "$URL/api/orders/$ORDER_ID" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["customer"])' 2>/dev/null)
  [ "$got" = Checker ]; result $? "Persistence: the order survives docker compose down and up" "order $ORDER_ID not found after restart"
else
  result 1 "Persistence: the order survives docker compose down and up" "no order to look for"
fi

# Hardening, read from the containers Compose created (not from the file). Works even when
# the stack didn't come up healthy, as long as the containers exist.
CREATED=0; [ "$HAVE_COMPOSE" = 1 ] && [ -n "$(compose ps -a -q 2>/dev/null)" ] && CREATED=1
hard() {  # $1 = label, $2 = docker inspect template that prints "ok" when the setting is right
  local label=$1 tpl=$2 bad=""
  if [ "$CREATED" != 1 ]; then result 1 "$label" "no containers"; return; fi
  for s in $SERVICES; do
    c=$(compose ps -a -q "$s"); [ -n "$c" ] || { bad="$bad $s(no container)"; continue; }
    [ "$(docker inspect -f "$tpl" "$c")" = ok ] || bad="$bad $s"
  done
  [ -z "$bad" ]; result $? "$label" "not set on:$bad"
}
hard "Hardening: read-only root filesystem on all 5 services" '{{if .HostConfig.ReadonlyRootfs}}ok{{end}}'
hard "Hardening: cap_drop ALL on all 5 services" '{{range .HostConfig.CapDrop}}{{if eq . "ALL"}}ok{{end}}{{end}}'
hard "Hardening: no-new-privileges on all 5 services" '{{range .HostConfig.SecurityOpt}}{{if eq . "no-new-privileges:true" "no-new-privileges"}}ok{{end}}{{end}}'
if [ "$CREATED" = 1 ]; then
  bad=""
  for s in $SERVICES; do
    c=$(compose ps -a -q "$s"); [ -n "$c" ] || { bad="$bad $s(no container)"; continue; }
    read -r mem pids < <(docker inspect -f '{{.HostConfig.Memory}} {{if .HostConfig.PidsLimit}}{{.HostConfig.PidsLimit}}{{else}}0{{end}}' "$c")
    [ "${mem:-0}" -gt 0 ] && [ "${pids:-0}" -gt 0 ] || bad="$bad $s(memory=$mem pids=$pids)"
  done
  [ -z "$bad" ]; result $? "Hardening: memory and PID limits on all 5 services" "missing on:$bad"
else
  result 1 "Hardening: memory and PID limits on all 5 services" "no containers"
fi

if [ "$STACK_UP" = 1 ]; then
  bad=""
  for s in $SERVICES; do
    c=$(compose ps -q "$s"); [ -n "$c" ] || { bad="$bad $s(not running)"; continue; }
    docker top "$c" -o pid,uid,comm 2>/dev/null | awk 'NR==1{ok=1} NR>1 && $2=="0"{f=1} END{exit (f || !ok)}' || bad="$bad $s"
  done
  [ -z "$bad" ]; result $? "Non-root at run time: no process in any of the 5 containers runs as uid 0" "root processes in:$bad"
else
  result 1 "Non-root at run time: no process in any of the 5 containers runs as uid 0" "stack not running"
fi

# ---------------------------------------------------------------- development
DEV_FILE=""
for f in compose.dev.yaml compose.override.yaml; do [ -f "$f" ] && DEV_FILE=$f && break; done
if [ -n "$DEV_FILE" ] && [ "$STACK_UP" = 1 ]; then
  docker compose -f compose.yaml -f "$DEV_FILE" config --format json > "$TMP/config.json" 2>/dev/null
  out=$(cfg watch); r=$?
  if [ "$r" = 0 ]; then
    # Live: start watch, change a front-end file, and look for the change through nginx
    compose -f "$DEV_FILE" up -d --wait --wait-timeout 180 > "$TMP/dev-up.log" 2>&1 || { r=1; out="dev stack did not start: $(tail -n 2 "$TMP/dev-up.log" | tr '\n' ' ')"; }
    if [ "$r" = 0 ]; then
      compose -f "$DEV_FILE" watch --no-up > "$TMP/watch.log" 2>&1 &
      WATCH_PID=$!
      sleep 5
      WATCH_FILE=web/index.html; cp "$WATCH_FILE" "$TMP/watch.bak"
      MARK="watch-check-$RANDOM"; echo "<!-- $MARK -->" >> "$WATCH_FILE"
      port=$(compose -f "$DEV_FILE" port web 8080 2>/dev/null | awk -F: '{print $NF}')
      r=1
      for _ in $(seq 20); do curl -fsS "http://127.0.0.1:$port/" 2>/dev/null | grep -q "$MARK" && { r=0; break; }; sleep 1; done
      cp "$TMP/watch.bak" "$WATCH_FILE"; WATCH_FILE=""
      sleep 2; kill "$WATCH_PID" 2>/dev/null; wait "$WATCH_PID" 2>/dev/null; WATCH_PID=""
      [ "$r" = 0 ] || out="an edit to web/index.html did not show up within 20 s ($(tail -n 2 "$TMP/watch.log" | tr '\n' ' '))"
    fi
  fi
  result $r "Dev override: $DEV_FILE has develop.watch for api, worker and web, and an edit syncs live" "$out"
else
  result 1 "Dev override: compose.dev.yaml has develop.watch for api, worker and web, and an edit syncs live" "$([ -z "$DEV_FILE" ] && echo 'no compose.dev.yaml' || echo 'stack not running')"
fi

# ---------------------------------------------------------------- security scan
if [ "${SKIP_SCAN:-0}" = 1 ]; then
  result 1 "Trivy: no fixable HIGH or CRITICAL vulnerabilities in api, worker and web" "skipped (SKIP_SCAN=1)"
elif [ "$BUILT" = 1 ]; then
  msg=""
  for s in $APP_SERVICES; do
    ref=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["services"][sys.argv[2]].get("image",""))' "$TMP/config.json" "$s")
    n=$(docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache "$TRIVY_IMAGE" \
          image --quiet --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --format json "$ref" 2>"$TMP/trivy.err" \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(len(r.get("Vulnerabilities") or []) for r in d.get("Results") or []))' 2>/dev/null)
    if [ -z "$n" ]; then msg="$msg $s: scan failed ($(tail -n 1 "$TMP/trivy.err"));"
    elif [ "$n" != 0 ]; then msg="$msg $s: $n;"; fi
    COUNTS="${COUNTS:-}$s $n, "
  done
  [ -z "$msg" ]; result $? "Trivy: no fixable HIGH or CRITICAL vulnerabilities in api, worker and web${COUNTS:+ (${COUNTS%, })}" "$msg"
else
  result 1 "Trivy: no fixable HIGH or CRITICAL vulnerabilities in api, worker and web" "nothing built"
fi

# ---------------------------------------------------------------- CI
P=pipeline.yml
if [ -f "$P" ]; then
  msg=""
  python3 -c 'import sys
try:
    import yaml; yaml.safe_load(open(sys.argv[1]))
except ImportError:
    pass' "$P" 2>/dev/null || msg="$msg not valid YAML;"
  grep -q 'npm test' "$P"                              || msg="$msg no 'npm test';"
  grep -qE 'pytest' "$P"                               || msg="$msg no pytest;"
  grep -qE 'docker/build-push-action' "$P"             || msg="$msg no docker/build-push-action;"
  grep -qE 'cache-from: *type=gha' "$P"                || msg="$msg no build cache (cache-from: type=gha);"
  grep -qE 'trivy' "$P"                                || msg="$msg no Trivy scan;"
  grep -qE -- '--exit-code[ =]1' "$P"                  || msg="$msg the scan doesn't fail the build (--exit-code 1);"
  grep -qE 'HIGH,CRITICAL' "$P"                        || msg="$msg the scan doesn't look at HIGH,CRITICAL;"
  grep -qE 'ghcr\.io' "$P"                             || msg="$msg no push to ghcr.io;"
  grep -qE 'packages: *write' "$P"                     || msg="$msg no 'packages: write' permission;"
  grep -qE "github.event_name != 'pull_request'" "$P"  || msg="$msg pushes from pull requests too;"
  grep -qE 'uses: [^@]+@(main|master)\b' "$P"          && msg="$msg an action is pinned to a branch;"
  [ -z "$msg" ]; result $? "Pipeline: pipeline.yml tests, builds with cache, scans (fails on HIGH/CRITICAL) and pushes to GHCR" "$msg"
else
  result 1 "Pipeline: pipeline.yml tests, builds with cache, scans (fails on HIGH/CRITICAL) and pushes to GHCR" "no pipeline.yml"
fi

echo
echo "Result: $PASSES of $N PASS, $FAILS FAIL"
echo "Also check by hand (see BRIEF.md): your pipeline ran green on GitHub Actions and pushed 3 images to ghcr.io."
[ "$FAILS" = 0 ]
