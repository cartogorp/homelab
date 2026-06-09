#!/usr/bin/env bash
set -euo pipefail

SERVER="homelab@whalesea"
LOCAL_DIR="./docker"
REMOTE_DIR="/srv/docker"

SERVICE="${1:-all}"

echo "==> Deploy mode: $SERVICE"

# -----------------------------
# Git safety checks (LOCAL ONLY)
# -----------------------------
echo "==> Checking local git state..."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR: Not a git repository"
  exit 1
}

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Working tree is not clean:"
  git status --short
  exit 1
fi

git fetch origin >/dev/null

LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})

if [[ "$LOCAL" != "$REMOTE" ]]; then
  echo "ERROR: Local branch is not in sync with origin"
  exit 1
fi

echo "==> Git state OK"

# -----------------------------
# DEPLOY ALL SERVICES
# -----------------------------
if [[ "$SERVICE" == "all" ]]; then

  echo "==> Full rsync deploy (authoritative sync)"

  rsync -avz --delete \
    --exclude='.git' \
    "$LOCAL_DIR/" \
    "$SERVER:$REMOTE_DIR/"

  ssh "$SERVER" bash -s << 'EOF'
set -euo pipefail

cd /srv/docker

echo "==> Rebuilding all compose stacks..."

for dir in */ ; do
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "-> $dir"
    docker compose -f "$dir/docker-compose.yml" up -d --remove-orphans
  fi
done

echo "==> Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}"
EOF

  echo "==> Deployment complete"
  exit 0
fi

# -----------------------------
# DEPLOY SINGLE SERVICE
# -----------------------------
echo "==> Service deploy: $SERVICE"

if [[ ! -d "$LOCAL_DIR/$SERVICE" ]]; then
  echo "ERROR: Service not found locally: $SERVICE"
  exit 1
fi

rsync -avz --delete \
  "$LOCAL_DIR/$SERVICE/" \
  "$SERVER:$REMOTE_DIR/$SERVICE/"

ssh "$SERVER" bash -s << EOF
set -euo pipefail

cd /srv/docker/$SERVICE

if [ ! -f "docker-compose.yml" ]; then
  echo "ERROR: docker-compose.yml not found for $SERVICE"
  exit 1
fi

echo "==> Rebuilding $SERVICE"
docker compose up -d --remove-orphans

docker ps --filter name=$SERVICE
EOF

echo "==> Deployment complete"
