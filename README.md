# Docker & NGINX Proxy Manager Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A hardened, interactive Bash installer for **Docker CE, Docker Compose, NGINX Proxy Manager (NPM), and Portainer-CE** on Linux — including ARM64 devices like Raspberry Pi.

Designed for homelab users, small-team DevOps, and anyone who wants a reproducible Docker host with a reverse proxy and a management UI behind a single command.

---

## Supported Operating Systems

- **Debian** 10 / 11 / 12
- **Ubuntu** 20.04 / 22.04 / 24.04 (x86_64 & ARM64)
- **Raspberry Pi OS** / Raspbian (ARM64)
- **CentOS / RHEL / Rocky / AlmaLinux / Fedora** (dnf or yum)
- **Arch Linux**
- **openSUSE** (Leap & Tumbleweed)

The script auto-detects your distribution via `/etc/os-release` (falling back to `ID_LIKE` for derivatives). If detection fails, you can select manually.

---

## Features

- **One-command setup** for a full Docker stack.
- **Pinned images** (NPM `2.12.1`, Portainer-CE `2.21.5`) — reproducible builds. Overridable via env vars.
- **Docker Compose v2 plugin** (`docker compose`, not the legacy binary).
- **Shared `main-net` network** so NPM can proxy other containers by hostname.
- **Healthchecks** configured for NPM (via `/bin/check-health`) and Portainer (HTTP spider).
- **Port-conflict detection** — checks `ss`/`netstat` before binding.
- **Idempotent reruns** — existing containers, compose files, and network are preserved.
- **Configurable ports** via environment variables (see below).
- **Distinguishes `sudo` vs pure root** — installs files into the invoking user's home and adds them to the `docker` group correctly.
- **Proper error propagation** — `set -Eeuo pipefail` plus a global `ERR` trap reporting source file, line, and function.
- **Log rotation** — each run archives the previous `~/install_docker_NPM.log` to `.old`.
- **Firewalld hint** on RHEL-family systems.
- Color-coded, interactive prompts; EOF-safe reads.

---

## Installation

```bash
curl -fsSL -o install_docker_NPM.sh \
  https://raw.githubusercontent.com/ibrahimaljuhani/docker_installs/main/install_docker_NPM.sh
chmod +x install_docker_NPM.sh
sudo ./install_docker_NPM.sh
```

> Must be run with `sudo` (or as root). Running with `sudo -E ./install_docker_NPM.sh` preserves env-var overrides.

---

## Environment Variable Overrides

Export before running to customize images or host ports:

| Variable | Default | Purpose |
|---|---|---|
| `NPM_IMAGE` | `jc21/nginx-proxy-manager:2.12.1` | NPM image tag |
| `NPM_HTTP_PORT` | `80` | Host port for public HTTP |
| `NPM_HTTPS_PORT` | `443` | Host port for public HTTPS |
| `NPM_ADMIN_PORT` | `81` | Host port for NPM admin UI |
| `PORTAINER_IMAGE` | `portainer/portainer-ce:2.21.5` | Portainer image tag |
| `PORTAINER_HTTP_PORT` | `9000` | Host port for Portainer HTTP |
| `PORTAINER_HTTPS_PORT` | `9443` | Host port for Portainer HTTPS |
| `PORTAINER_EDGE_PORT` | `8000` | Host port for Portainer Edge agent |

Example (move NPM HTTP to 8080):

```bash
NPM_HTTP_PORT=8080 NPM_HTTPS_PORT=8443 sudo -E ./install_docker_NPM.sh
```

---

## Default Credentials

### NGINX Proxy Manager
- URL: `http://YOUR_SERVER_IP:81` (or `$NPM_ADMIN_PORT`)
- Email: `admin@example.com`
- Password: `changeme`

> Change these on first login.

### Portainer-CE
- URL: `http://YOUR_SERVER_IP:9000` or `https://YOUR_SERVER_IP:9443`
- First login: create your own admin account.

---

## Directory Layout After Install

```
~/docker/
└── npm/
    ├── docker-compose.yml
    ├── data/            # NPM SQLite DB + config
    └── letsencrypt/     # TLS certs
```

Portainer stores its data in the Docker volume `portainer_data`.

---

## Security Notes

- **Portainer mounts `/var/run/docker.sock`.** Anyone who can reach Portainer effectively has root on the host. Protect the admin UI behind a firewall, VPN, or reverse proxy with auth.
- **NPM default credentials must be changed immediately.**
- **Docker group = root equivalent.** Be careful who you add.
- The script pins image tags but does **not** verify checksums of the `get.docker.com` script. If this is a concern, install Docker from your distribution's repository instead.

---

## Troubleshooting

**Port already in use**
The script pre-checks ports via `ss`/`netstat`. If a port is busy it prompts to continue. To change ports, re-run with env vars (see above).

**`docker` command requires sudo after install**
Log out and back in (or reboot) — group membership is a new-session thing.

**Services unreachable on RHEL/Fedora**
`firewalld` blocks ports even though Docker bypasses `ufw`. The script prints the exact `firewall-cmd` lines at the end.

**Containers not running**
```bash
cd ~/docker/npm && docker compose logs
docker logs portainer
```

**Installation failed mid-way**
Check the log: `~/install_docker_NPM.log`. The previous run's log (if any) is preserved as `~/install_docker_NPM.log.old`.

---

## System Requirements

- 1 GB RAM minimum (2 GB recommended)
- ~10 GB free disk
- Internet access during install

---

## License

MIT — see [LICENSE](LICENSE).

---

## Author

**Ibrahim Aljuhani** — [@ibrahimaljuhani](https://github.com/ibrahimaljuhani)
