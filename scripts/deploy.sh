#!/usr/bin/env bash
set -euo pipefail

SERVER="homelab@whalesea"
REMOTE_DIR="/srv/docker"

SERVICE="${1:-all}"
DRY_RUN="${DRY_RUN:-false}"

echo "==> Deploy mode: $SERVICE"

# -----------------------------
# Git safety checks (LOCAL)
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
# DEPLOY ALL (recommended path)
# -----------------------------
if [[ "$SERVICE" == "all" ]]; then

  echo "==> Full deploy (git pull + restart stacks)"

  ssh "$SERVER" bash -s << 'EOF'
set -euo pipefail

cd /srv/docker

echo "==> Pulling latest from git..."
git pull

echo "==> Restarting all compose stacks..."

# Only directories containing compose files
for dir in docker/*/ ; do
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "-> $dir"
    docker compose -f "$dir/docker-compose.yml" up -d --remove-orphans
  fi
done

echo "==> Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}"
EOF

  exit 0
fi

# -----------------------------
# DEPLOY SINGLE SERVICE
# -----------------------------
echo "==> Service deploy: $SERVICE"

ssh "$SERVER" bash -s << EOF
set -euo pipefail

cd /srv/docker

echo "==> Pulling latest from git..."
git pull

COMPOSE_FILE="docker/$SERVICE/docker-compose.yml"

if [ ! -f "\$COMPOSE_FILE" ]; then
  echo "ERROR: Compose file not found: \$COMPOSE_FILE"
  exit 1
fi

echo "==> Deploying \$SERVICE"
docker compose -f "\$COMPOSE_FILE" up -d --remove-orphans

echo "==> Status:"
docker ps --filter name=$SERVICE
EOF

echo "==> Deployment complete"
