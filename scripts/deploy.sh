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
      shift
      ;;
    *)
      SERVICE="$arg"
      ;;
  esac
done

echo "==> Deploy mode: $SERVICE"
[[ "$DRY_RUN" == true ]] && echo "==> DRY RUN ENABLED (no changes will be made)"

# -----------------------------
# Git safety checks
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
    echo "Would rsync: ./docker/ -> $SERVER:$REMOTE_DIR (WITH --delete)"
    echo "Would restart all compose stacks on server"
  else
    echo "[SERVICE MODE]"
    echo "Would rsync: ./docker/$SERVICE -> $SERVER:$REMOTE_DIR/$SERVICE"
    echo "Would restart ONLY service: $SERVICE"
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

  echo "==> Full deploy (authoritative sync)"

  rsync -av --delete --exclude='.git' ./docker/ "$SERVER:$REMOTE_DIR/"

  ssh "$SERVER" bash -s << 'EOF'
    set -euo pipefail
    cd /srv/docker

    for dir in */ ; do
      if [ -f "$dir/docker-compose.yml" ]; then
        echo "-> Updating $dir"
        cd "$dir"
        docker compose pull
        docker compose up -d --remove-orphans
        cd ..
      fi
    done

    docker ps --format "table {{.Names}}\t{{.Status}}"
EOF

else

  echo "==> Service deploy (safe mode): $SERVICE"

  if [[ ! -d "./docker/$SERVICE" ]]; then
    echo "ERROR: Service '$SERVICE' not found"
    exit 1
  fi

  rsync -av ./docker/$SERVICE/ "$SERVER:$REMOTE_DIR/$SERVICE/"

  ssh "$SERVER" bash -s << EOF
    set -euo pipefail
    cd /srv/docker/$SERVICE

    docker compose pull
    docker compose up -d --remove-orphans

    docker ps --filter name=$SERVICE
EOF

fi

echo "==> Deployment complete"
