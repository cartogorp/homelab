# Homelab (whalesea)

This repository documents and manages the configuration for my home server **whalesea**.

The server is a headless Ubuntu-based system accessed primarily via SSH, with optional remote access via Tailscale.

---

## 🧠 Design Goals

- Headless-first server (no reliance on a monitor/GUI)
- Fully SSH-managed administration
- Reproducible infrastructure using version-controlled configs
- Clear separation between configuration (Git) and runtime data (/srv)
- Easy recovery and rebuild from scratch
- Support for media hosting, game streaming, and self-hosted services

---

## 🖥️ Server Overview

- Hostname: whalesea
- User: homelab
- OS: Ubuntu Server
- Primary access: SSH
- Remote access: Tailscale mesh VPN
- Local IP: 192.168.86.144 (DHCP reservation)

---

## 🔐 Access

SSH is used for all administration:

ssh whalesea

Authentication is key-based only. Password login is disabled or will be disabled once stable.

---

## 🌐 Tailscale Access

Tailscale is used for secure remote administration without exposing SSH to the internet.

Command used on server:

sudo tailscale up

---

## 📁 Filesystem Layout

### Runtime data (server-side)

/srv/
├── docker/     Docker Compose stacks
├── media/      Jellyfin media library
├── downloads/  Temporary downloads
└── appdata/    Service data (databases, configs)

---

### Git-managed configuration (this repo)

~/homelab/
├── docker/     Compose files per service
├── scripts/    Utility scripts
└── README.md

---

## 🐳 Docker Strategy

- Each service lives in its own directory
- Persistent data is always mounted from /srv
- Docker Compose used for service definitions
- Containers are treated as ephemeral (rebuildable)

Example:

/srv/docker/jellyfin/
├── compose.yml
└── config/

---

## 🎬 Planned Services

### Media Server
- Jellyfin for media streaming

### Game Streaming (future)
- Steam Big Picture Mode
- Sunshine for Moonlight streaming

### Infrastructure (future)
- Reverse proxy (Caddy or Traefik)
- Monitoring / dashboards

---

## 🔄 Backup Strategy (planned)

- Configuration: stored in Git (~/homelab)
- Data: external backup target (TBD)
- Media: partially rebuildable depending on importance

---

## ⚠️ Security Notes

- SSH access is key-based only
- Password authentication should be disabled once stable
- Tailscale is used for secure remote access
- No public SSH exposure to the internet

---

## 🚧 Status

Current stage:
Foundation setup complete (SSH + networking + remote access)

Next step:
Docker installation and first service deployment (Jellyfin)
