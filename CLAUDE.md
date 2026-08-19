# Homelab

This repository is the source of truth for the configuration deployed
to whalesea.

## Important rules

- Do not expose or print secrets from `.env` files.
- Do not commit secrets.
- Do not deploy changes automatically.
- Do not run destructive Docker commands without asking first.
- Review changes with git diff before deployment.

## Deployment

The server is updated using:

./scripts/deploy.sh

The deployment target is whalesea.
