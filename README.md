# Homelab (whalesea)

This repository manages the infrastructure for my home server whalesea.

It includes:
- Docker-based services
- Systemd-managed Python services
- Custom deployment automation
- Shared storage under /srv

---

## Architecture Overview

The system has two runtime layers:

### Docker Layer

Location: /srv/docker

Used for containerized applications.

Each service contains:
- docker-compose.yml
- optional config and data directories

Deployed via rsync and docker compose restart.

---

### Systemd Python Services Layer

Location: /srv/services

Used for long-running Python services.

Each service contains:
- main Python script (example: transcribe.py)
- requirements.txt
- venv directory
- systemd service file

---

## Deployment System

Deployment command:

./scripts/deploy.sh <service|docker|services|all>

Features:
- Git state validation
- rsync-based synchronization
- automatic service detection
- automatic venv creation for Python services
- automatic dependency installation from requirements.txt
- systemd restart after deployment

---

## Whisper Service

The Whisper service:

- Watches /srv/storage/whisper/uploads
- Transcribes audio using faster-whisper
- Outputs text files to /srv/storage/whisper/transcripts
- Runs continuously using systemd and watchdog

---

## Filesystem Layout

/srv/docker → Docker services
/srv/services → Systemd Python services
/srv/storage → Shared application data

---

## Whisper Storage

/srv/storage/whisper/uploads → incoming audio files
/srv/storage/whisper/transcripts → output text files
/srv/storage/whisper/processed → optional archive folder

---

## Server Overview

Hostname: whalesea  
User: homelab  
OS: Ubuntu Server  
Access: SSH key-based only  
Remote access: Tailscale VPN  

---

## Security Model

- No password SSH login
- SSH key authentication only
- Services run locally unless explicitly exposed
- Tailscale used for remote access

---

## Design Principles

- Infrastructure defined in Git
- Runtime lives in /srv
- Docker = packaged services
- Systemd = custom long-running services
- Deploy script is the single source of truth for updates

---

## Current Status

Working:
- Docker orchestration
- Systemd service framework
- Whisper transcription pipeline
- Deployment automation
- Storage structure under /srv
- Reverse proxy (Caddy)

Next:
- logging improvements
- backups
- service standardization
- Shelfmark for CWA
- Kavita + send to kindle setup
- CWA KoSync
