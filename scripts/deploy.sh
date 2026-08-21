#!/usr/bin/env bash
set -euo pipefail

SERVER="homelab@whalesea"

LOCAL_DOCKER_DIR="./docker"
REMOTE_DOCKER_DIR="/srv/docker"

LOCAL_SERVICES_DIR="./services"
REMOTE_SERVICES_DIR="/srv/services"

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

  rsync -avz \
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

  rsync -avz \
    --exclude 'venv/' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "$LOCAL_SERVICES_DIR/" \
    "$SERVER:$REMOTE_SERVICES_DIR/"

ssh "$SERVER" bash -s << 'EOF'
set -euo pipefail

for dir in /srv/services/*/ ; do
  service=$(basename "$dir")
  unit="/srv/services/$service/$service.service"

  if [ -f "$unit" ]; then
    echo "-> installing $service.service"
    sudo install -m 644 "$unit" "/etc/systemd/system/$service.service"
  fi
done

sudo systemctl daemon-reload

for dir in /srv/services/*/ ; do
  service=$(basename "$dir")

  if systemctl is-enabled --quiet "$service"; then
    echo "-> restarting $service"
    sudo systemctl restart "$service"
    sudo systemctl is-active --quiet "$service"
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

  rsync -avz \
    --exclude 'venv/' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "$LOCAL_DOCKER_DIR/$SERVICE/" \
    "$SERVER:$REMOTE_DOCKER_DIR/$SERVICE/"

  ssh "$SERVER" bash -s -- "$SERVICE" << EOF
set -euo pipefail

SERVICE="$1"

cd /srv/docker/$SERVICE
docker compose pull
docker compose up -d --remove-orphans
EOF

  echo "==> Docker service deployed"
  exit 0
fi

# ---- Systemd service
if [[ -d "$LOCAL_SERVICES_DIR/$SERVICE" ]]; then

  echo "==> Systemd service detected: $SERVICE"

  rsync -avz \
    --exclude 'venv/' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "$LOCAL_SERVICES_DIR/$SERVICE/" \
    "$SERVER:$REMOTE_SERVICES_DIR/$SERVICE/"

  ssh "$SERVER" bash -s -- "$SERVICE" << 'EOF'
set -euo pipefail

SERVICE="$1"

cd "/srv/services/$SERVICE"

# -----------------------------
# Ensure venv exists
# -----------------------------
if [ ! -d "venv" ]; then
  echo "==> Creating venv"
  python3 -m venv venv
fi

# -----------------------------
# Install dependencies
# -----------------------------
if [ -f "requirements.txt" ]; then
  echo "==> Installing dependencies"

  ./venv/bin/python -m ensurepip --upgrade || true
  ./venv/bin/python -m pip install --upgrade pip
  ./venv/bin/python -m pip install -r requirements.txt
else
  echo "WARNING: No requirements.txt found for $SERVICE"
fi

# -----------------------------
# Install systemd unit
# -----------------------------
if [ -f "$SERVICE.service" ]; then
  echo "==> Installing systemd unit"
sudo /usr/local/sbin/install-systemd-unit \
  "/srv/services/$SERVICE/$SERVICE.service" \
  "$SERVICE.service"
fi

sudo systemctl daemon-reload

echo "==> Restarting $SERVICE"
sudo systemctl restart "$SERVICE"

echo "==> Checking $SERVICE status"
sudo systemctl is-active --quiet "$SERVICE"
sudo systemctl status "$SERVICE" --no-pager

EOF

  echo "==> Systemd service deployed"
  exit 0
fi

echo "ERROR: Unknown service: $SERVICE"
exit 1
