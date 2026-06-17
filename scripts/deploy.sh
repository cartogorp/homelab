#!/usr/bin/env bash
set -euo pipefail

SERVER="homelab@whalesea"

LOCAL_DOCKER_DIR="./docker"
REMOTE_DOCKER_DIR="/srv/docker"

LOCAL_SERVICES_DIR="./services"
REMOTE_SERVICES_DIR="/opt"

SERVICE="${1:-all}"

echo "==> Deploy mode: $SERVICE"

# -----------------------------
# Git safety checks
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
# ALL DEPLOY
# -----------------------------
if [[ "$SERVICE" == "all" ]]; then

  echo "==> Deploying ALL docker + services"

  "$0" docker
  "$0" services

  echo "==> Full deploy complete"
  exit 0
fi

# -----------------------------
# DOCKER MODE (deploy all docker stacks)
# -----------------------------
if [[ "$SERVICE" == "docker" ]]; then

  echo "==> Deploying all docker services"

  rsync -avz --delete \
    --exclude='.git' \
    "$LOCAL_DOCKER_DIR/" \
    "$SERVER:$REMOTE_DOCKER_DIR/"

  ssh "$SERVER" bash -s << 'EOF'
set -euo pipefail

cd /srv/docker

for dir in */ ; do
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "-> restarting $dir"
    docker compose -f "$dir/docker-compose.yml" up -d --remove-orphans
  fi
done
EOF

  echo "==> Docker deploy complete"
  exit 0
fi

# -----------------------------
# SERVICES MODE (systemd services)
# -----------------------------
if [[ "$SERVICE" == "services" ]]; then

  echo "==> Deploying all systemd services"

  rsync -avz --delete \
    "$LOCAL_SERVICES_DIR/" \
    "$SERVER:$REMOTE_SERVICES_DIR/"

  ssh "$SERVER" bash -s << 'EOF'
set -euo pipefail

sudo systemctl daemon-reload || true

for dir in /opt/*/ ; do
  service=$(basename "$dir")

  if systemctl list-unit-files | grep -q "^${service}.service"; then
    echo "-> restarting $service"
    sudo systemctl restart "$service" || true
  fi
done
EOF

  echo "==> Services deploy complete"
  exit 0
fi

# -----------------------------
# SINGLE TARGET AUTO-DETECTION
# -----------------------------
echo "==> Target deploy: $SERVICE"

# ---- Docker service
if [[ -d "$LOCAL_DOCKER_DIR/$SERVICE" ]]; then

  echo "==> Docker service detected: $SERVICE"

  rsync -avz --delete \
    "$LOCAL_DOCKER_DIR/$SERVICE/" \
    "$SERVER:$REMOTE_DOCKER_DIR/$SERVICE/"

  ssh "$SERVER" bash -s << EOF
set -euo pipefail

cd /srv/docker/$SERVICE
docker compose up -d --remove-orphans
EOF

  echo "==> Docker service deployed"
  exit 0
fi

# ---- Systemd service
if [[ -d "$LOCAL_SERVICES_DIR/$SERVICE" ]]; then

  echo "==> Systemd service detected: $SERVICE"

  rsync -avz --delete \
    "$LOCAL_SERVICES_DIR/$SERVICE/" \
    "$SERVER:$REMOTE_SERVICES_DIR/$SERVICE/"

  ssh "$SERVER" bash -s << EOF
set -euo pipefail

sudo systemctl daemon-reload || true
sudo systemctl restart "$SERVICE" || true
sudo systemctl status "$SERVICE" --no-pager || true
EOF

  echo "==> Systemd service deployed"
  exit 0
fi

echo "ERROR: Unknown service: $SERVICE"
exit 1
