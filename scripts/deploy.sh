#!/usr/bin/env bash
set -euo pipefail

SERVER="homelab@whalesea"
REMOTE_DIR="/srv/docker"

DRY_RUN=false
SERVICE="all"

# -----------------------------
# Parse args
# -----------------------------
for arg in "$@"; do
  case $arg in
    --dry)
      DRY_RUN=true
      ;;
    *)
      SERVICE="$arg"
      ;;
  esac
done

echo "==> Deploy mode: $SERVICE"
[[ "$DRY_RUN" == true ]] && echo "==> DRY RUN ENABLED (no changes will be made)"

# -----------------------------
# Git safety checks (LOCAL)
# -----------------------------
echo "==> Checking git state..."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR: Not a git repository"
  exit 1
}

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Working tree is not clean."
  git status --short
  exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "main" ]]; then
  echo "ERROR: Not on main branch (currently $BRANCH)"
  exit 1
fi

git fetch origin

LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})

if [[ "$LOCAL" != "$REMOTE" ]]; then
  echo "ERROR: Local branch not in sync with origin/main"
  exit 1
fi

echo "==> Git state OK"

# -----------------------------
# DRY RUN MODE
# -----------------------------
if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "==== DRY RUN SUMMARY ===="
  echo "Server: $SERVER"
  echo "Remote dir: $REMOTE_DIR"
  echo "Service: $SERVICE"
  echo ""

  if [[ "$SERVICE" == "all" ]]; then
    echo "[ALL SERVICES MODE]"
    echo "Would: git pull on server"
    echo "Would: restart ALL compose stacks"
  else
    echo "[SERVICE MODE]"
    echo "Would: git pull on server"
    echo "Would: restart ONLY service: $SERVICE"
  fi

  echo ""
  echo "Git state:"
  git log --oneline -5
  exit 0
fi

# -----------------------------
# DEPLOY
# -----------------------------
if [[ "$SERVICE" == "all" ]]; then

  echo "==> Full deploy"

  ssh "$SERVER" bash -s << 'EOF'
set -euo pipefail

cd /srv/docker

echo "==> Pulling latest changes..."
git pull

echo "==> Rebuilding all stacks..."

for dir in */ ; do
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "-> Updating $dir"
    docker compose -f "$dir/docker-compose.yml" up -d --remove-orphans
  fi
done

echo "==> Deployment complete"
docker ps --format "table {{.Names}}\t{{.Status}}"
EOF

else

  echo "==> Service deploy: $SERVICE"

  ssh "$SERVER" bash -s << EOF
set -euo pipefail

cd /srv/docker

echo "==> Pulling latest changes..."
git pull

if [ ! -d "$SERVICE" ]; then
  echo "ERROR: Service '$SERVICE' not found in /srv/docker"
  exit 1
fi

cd "$SERVICE"

echo "==> Restarting service: $SERVICE"
docker compose up -d --remove-orphans

echo "==> Done"
docker ps --filter name="$SERVICE"
EOF

fi

echo "==> Deployment complete"
