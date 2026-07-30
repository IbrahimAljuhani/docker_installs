# 🐳 Odoo Docker Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Odoo Versions](https://img.shields.io/badge/Odoo-17.0%20%7C%2018.0%20%7C%2019.0%20%7C%20Custom-blueviolet)](#-odoo-version-notes)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](#)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-336791?logo=postgresql&logoColor=white)](#)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](#)

A smart, interactive Bash installer that spins up **production-ready Odoo instances in Docker**, using **official Docker Hub images only**. It handles multi-instance isolation, correct file permissions, real-time WebSocket support, resource limits, and secure credential generation — built for **Ubuntu/Debian** servers.

Perfect for developers, agencies, and businesses running **multiple isolated Odoo instances** on the same host with minimal manual setup.

> 🔗 **Prerequisite**: Docker CE, Docker Compose, `openssl`, and `curl`.
> Don't have Docker yet? Use: <https://github.com/IbrahimAljuhani/docker_installs>

---

## 📑 Table of Contents

- [Features](#-features)
- [How It Works](#-how-it-works)
- [Installation & Usage](#-installation--usage)
- [First Run — Creating the Database](#-first-run--creating-the-database)
- [Directory Structure](#-directory-structure)
- [Security](#-security)
- [Management Commands](#️-management-commands)
- [Reverse Proxy & SSL](#-reverse-proxy--ssl-recommended)
- [Complete Cleanup](#-complete-cleanup)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Odoo Version Notes](#-odoo-version-notes)
- [Changelog](#-changelog)
- [License](#-license)

---

## ✅ Features

| Category | Details |
|---|---|
| 🖼️ **Official images only** | `odoo:<version>` and `postgres:17` from Docker Hub — or bring your own custom image |
| 🧩 **Multi-instance support** | Run several isolated Odoo instances side-by-side (`odoo-prod`, `odoo-dev`, ...), each with its own network, volumes, and ports |
| ⚙️ **Automatic setup** | Generates `.env`, `docker-compose.yml`, and `odoo.conf` for you — no manual editing needed |
| 🔐 **Secure by default** | Random 20-character passwords for DB and Odoo admin; secrets saved with `600` permissions |
| 🏷️ **Version flexibility** | Odoo **17.0 (LTS)**, **18.0 (Stable)**, **19.0 (Dev)**, or a **custom image** of your choice |
| 🔎 **Custom image validation** | Checks your custom image exists locally or on the registry before proceeding — no silent typos |
| 🆔 **Correct file ownership** | Auto-detects the real UID/GID of the `odoo` user *inside the image* (instead of assuming `100:101`) and applies it to bind-mounted folders |
| 💬 **Real-time WebSocket support** | Exposes and enables the `gevent`/longpolling worker (port `8072`) — Live Chat, POS sync, and bus notifications work out of the box |
| ❤️ **Health checks** | Both Odoo and PostgreSQL containers ship with working `healthcheck` definitions |
| 📊 **Resource limits** | Memory limits applied via `mem_limit`/`mem_reservation` (so they actually work with plain `docker compose`, not just Swarm) |
| 🗃️ **Isolated, durable storage** | Each instance gets its own Postgres volume, Odoo filestore volume, addons folder, and config file |
| 🧼 **No system pollution** | Everything runs in containers — nothing installed globally on the host |

---

## 🧠 How It Works

```
                         ┌─────────────────────────────────────────┐
                         │        odoo-net-<instance>  (bridge)     │
                         │                                           │
   Host                  │   ┌───────────────┐     ┌───────────────┐│
   ─────                 │   │   odoo         │     │   db          ││
   HTTP  → :ODOO_PORT ───┼──►│   :8069        │────►│  postgres:17  ││
   WS    → :WS_PORT   ───┼──►│   :8072 gevent │     │  (internal    ││
                         │   │                │     │   only)       ││
                         │   └───────┬───────┘     └───────────────┘│
                         │           │                               │
                         └───────────┼───────────────────────────────┘
                                     │
                         ┌───────────▼───────────┐
                         │  named volume:         │
                         │  odoo-data             │  ← filestore & sessions
                         │  (correct ownership,    │    (never a bind mount)
                         │   managed by Docker)    │
                         └────────────────────────┘

   Bind mounts (host ⇄ container, read from host):
     ./config  → /etc/odoo         (odoo.conf)
     ./addons  → /mnt/extra-addons (your custom modules)
     ./db-data → /var/lib/postgresql/data
```

Key design decisions baked into the script:

- **`POSTGRES_DB` is set to `postgres`, not the instance's database name.** Odoo creates and initializes its own database the first time you open the database manager. Pre-creating an empty database with the instance's name would make Odoo think it's already initialized and crash with `ir_module_module does not exist`.
- **The Odoo filestore (`/var/lib/odoo`) is a named Docker volume**, not a bind-mounted host folder — this avoids the classic `Permission denied: /var/lib/odoo/sessions` error caused by UID mismatches between the host and the container.
- **`config/` and `addons/`** stay as bind mounts (you need to edit them from the host), but the script chowns them to the *actual* UID/GID of the `odoo` user inside the image you picked — detected dynamically, not hardcoded.
- **The `odoo` app container also joins the shared `main-net` network** (the same one created by [`install_docker_core.sh`](../../install_docker_core.sh)), so NGINX Proxy Manager can reach it directly by container name (`odoo-<instance>:8069`) — no host port needs to stay published just for the proxy. `db` stays off `main-net` and is only reachable from `odoo` over the private `odoo-net-<instance>` network.

---

## 📥 Installation & Usage

### 1. Install Prerequisites (Docker + Compose)

```bash
curl -fsSL -o install_docker_core.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/docker_installs/main/install_docker_core.sh
chmod +x install_docker_core.sh
sudo ./install_docker_core.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed). ✅ This also installs **NGINX Proxy Manager** and **Portainer CE** (optional, recommended for production), and creates the shared `main-net` network this service attaches to.

### 2. Download and Run the Installer

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/docker_installs/main/services/odoo/deploy.sh
chmod +x deploy.sh
./deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.
> Add yourself with `sudo usermod -aG docker $USER`, then log out and back in.
> 💡 For smoother automatic permission fixes, having **passwordless `sudo`** cached (`sudo -v`) before running is recommended but not required.

### You'll be guided through:

| # | Prompt | Notes |
|---|---|---|
| 1 | **Instance name** (e.g. `odoo-shop`) | Validated: lowercase letters, digits, `-`, `_` only |
| 2 | **Odoo version** | `19.0` (dev) / `18.0` (stable) / `17.0` (LTS) / **Custom image** |
| 3 | **HTTP port** | Default `8069`, checked for conflicts |
| 4 | **WebSocket/longpolling port** | Default = HTTP port `+ 3` (e.g. `8072`), checked for conflicts |
| 5 | **PostgreSQL username** | Default `odoo` |
| 6 | **PostgreSQL password** | Auto-generated if left blank |
| 7 | **Database name** | Just a *label* — see next section, it isn't created yet |

---

## 🚀 First Run — Creating the Database

Unlike installers that pre-create the database for you, this script lets **Odoo create and initialize its own database** — the correct way to avoid a broken, half-initialized schema.

After the containers start, open:

```
http://<server-ip>:<ODOO_PORT>/web/database/manager
```

Click **Create Database** and use:
- **Master Password** → the `Admin Pass` printed at the end of installation
- **Database Name** → the name you entered during setup

Odoo will create the schema and install the `base` module automatically. This step is required only once per instance.

---

## 📁 Directory Structure

```
~/docker/odoo/
└── your-instance-name/
    ├── .env                  # DB credentials & admin password        (600)
    ├── docker-compose.yml    # Stack definition
    ├── config/
    │   └── odoo.conf         # Odoo config (db host, workers, gevent)  (640, owned by the container's odoo uid)
    ├── addons/                # Your custom modules                    (owned by the container's odoo uid)
    └── db-data/               # PostgreSQL data (bind-mounted volume)
```

> 📝 Note: the Odoo filestore/session data is **not** a folder here — it lives in a Docker-managed named volume (`odoo-data`), inspectable with `docker volume inspect odoo-data`.

Example with multiple instances:

```
~/docker/odoo/
├── odoo-prod/
├── odoo-staging/
└── odoo-dev/
```

---

## 🔐 Security

- **Admin password** and **DB password**: auto-generated, 20-character alphanumeric.
- **`~/docker/odoo/.odoo-docker-secrets.txt`**: append-only log of every instance's credentials, `600` permissions.
- **`.env`**: `600` permissions, per instance.
- **`config/odoo.conf`**: owned by the container's `odoo` user and locked to `640` — readable by the container, not world-readable. (Falls back to `644` with a warning if ownership can't be changed, e.g. no `sudo` access — the container must be able to read its own config to start.)
- **PostgreSQL is never exposed on the host** — it's reachable only from the Odoo container over the internal `odoo-net-<instance>` bridge network.

```
🔒  SECURITY REMINDER
    1. Save credentials from: ~/docker/odoo/.odoo-docker-secrets.txt
    2. Clear your terminal history: history -c && history -w
```

---

## 🛠️ Management Commands

```bash
cd ~/docker/odoo/your-instance-name
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f` | Follow live logs (both containers) |
| `docker compose logs odoo` | Odoo logs only |
| `docker compose logs db` | PostgreSQL logs only |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose restart` | Restart all containers |
| `docker compose down` | Stop & remove containers (data preserved) |
| `docker compose down -v` | ⚠️ Also deletes the `odoo-data` volume and Postgres data |
| `docker compose pull` | Pull the latest image versions |

---

## 🌐 Reverse Proxy & SSL (Recommended)

Odoo needs **two upstreams** behind your proxy: the main HTTP port and the WebSocket/longpolling port.

### Option A: NGINX Proxy Manager (GUI)

Since the `odoo` container shares the `main-net` network with NPM, proxy to it **by container name** instead of `127.0.0.1:<port>` — this works even if you stop publishing the Odoo ports on the host.

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: `odoo.yourdomain.com`
   - **Forward Hostname/IP**: `odoo-<instance>` (e.g. `odoo-prod`)
   - **Forward Port**: `8069`
   - Enable **Websockets Support**
3. On the **Advanced** tab, add a custom location so `/websocket` routes to the longpolling port:
   ```nginx
   location /websocket {
       proxy_pass http://odoo-<instance>:8072;
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
   }
   ```
4. Enable **SSL** with Let's Encrypt from the UI.

✅ No need to expose ports publicly — NPM handles HTTPS termination and WebSocket routing over `main-net`.

### Option B: Certbot + Nginx (Manual)

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo certbot --nginx -d odoo.yourdomain.com
```

---

## 🧹 Complete Cleanup

To completely remove an instance (containers + all data, including the database and filestore):

```bash
cd ~/docker/odoo/your-instance-name
docker compose down -v      # removes containers, network, AND the odoo-data named volume
cd ~
rm -rf ~/docker/odoo/your-instance-name   # removes db-data, config, addons, docker-compose.yml, .env
```

> ⚠️ `-v` deletes the `odoo-data` named volume (Odoo filestore/sessions) — that's not stored under `~/docker/odoo/...` so a plain `rm -rf` alone won't touch it. You need **both** commands for a truly complete wipe. PostgreSQL's `db-data`, on the other hand, *is* a regular folder on disk, so `rm -rf` alone removes it (with or without `-v`).

To remove only the containers and keep all data intact (so you can recreate them later with `docker compose up -d`):

```bash
cd ~/docker/odoo/your-instance-name
docker compose down
```

---

```bash
# Resource usage (live)
docker stats odoo-your-instance-name odoo-your-instance-name-db

# Container health status
docker inspect --format='{{.State.Health.Status}}' odoo-your-instance-name

# Confirm the WebSocket/gevent worker is running
docker exec odoo-your-instance-name ps aux | grep gevent

# PostgreSQL active connections (replace DB_USER with what you entered)
docker exec odoo-your-instance-name-db \
  psql -U <DB_USER> -d postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Database size (replace DB_NAME/DB_USER accordingly)
docker exec odoo-your-instance-name-db \
  psql -U <DB_USER> -d <DB_NAME> -c "SELECT pg_size_pretty(pg_database_size('<DB_NAME>'));"
```

---

## 🩺 Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `relation "ir_module_module" does not exist` | An old/other script pre-created the database | Not an issue with this script — `POSTGRES_DB` is always `postgres` here. Create the DB via `/web/database/manager` |
| `Permission denied: /var/lib/odoo/sessions` | Filestore was bind-mounted with wrong ownership | N/A here — filestore uses a named volume. If you customized this, switch back to `odoo-data:/var/lib/odoo` |
| Container stuck in a **restart loop**, logs show `NoSectionError: No section: 'options'` or `grep: /etc/odoo/odoo.conf: Permission denied` | `config/odoo.conf` isn't readable by the container's odoo user | `sudo chown <uid>:<gid> config/odoo.conf && sudo chmod 640 config/odoo.conf` (uid/gid printed during install), then `docker compose up -d` |
| `ps aux \| grep gevent` shows nothing | `workers` isn't ≥ 1 in `odoo.conf` | Gevent only starts in multi-worker mode — this script sets `workers = 2` by default; verify it wasn't edited out |
| `No write permission for ~/docker/odoo` | The **top-level** `~/docker/odoo` folder ownership got changed (e.g. by a broad `chown -R`) | `sudo chown $(whoami):$(whoami) ~/docker/odoo` (no `-R` — don't touch existing instances' internal permissions) |
| `chmod: ... Operation not permitted` while creating a new instance | A file was `chown`'d to another user (e.g. via `sudo`) and then `chmod`'d without `sudo` | Fixed in the current script version — update if you're on an older copy |

---

## 📌 Odoo Version Notes

| Version | Status | Notes |
|---|---|---|
| **19.0** | ⚠️ Beta | Development branch — an official Docker image may not exist yet |
| **18.0** | ✅ Stable | Recommended for new production deployments |
| **17.0** | ✅ LTS | Long-term support — safe for existing production |
| **Custom** | 🧩 Your responsibility | Any `repo/image:tag` reachable locally or on a registry; UID/GID and image existence are auto-verified |

---

## 🗒️ Changelog

- **PostgreSQL 15 → 17**
- Fixed database initialization flow (`POSTGRES_DB=postgres`, Odoo creates its own DB)
- Filestore moved from a bind mount to a named Docker volume (fixes permission errors)
- Dynamic UID/GID detection for the container's `odoo` user (replaces hardcoded `100:101`)
- WebSocket/longpolling support: port `8072` exposed, `workers`/`gevent_port` configured
- Added **custom image** option with existence validation
- `mem_limit`/`mem_reservation` added so memory limits actually apply outside Swarm
- Healthcheck switched from `curl` (not guaranteed present) to bundled `python3`
- `odoo.conf` ownership/permissions hardened without breaking container readability
- Input validation extended to DB username/name

---

## 📜 License

Licensed under the **MIT License** — see [LICENSE](./LICENSE).

---

## 🙌 Author

**Ibrahim Aljuhani**
GitHub: [@IbrahimAljuhani](https://github.com/IbrahimAljuhani)
