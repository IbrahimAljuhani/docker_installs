# 🧱 Services

Optional services that run on top of the core infrastructure ([`install_docker_core.sh`](../install_docker_core.sh) — Docker CE, Compose, NGINX Proxy Manager, Portainer, and the shared `main-net` network). Each one lives in its own folder here, is deployed independently, and you only run the ones you actually need.

---

## 📋 Available Services

| Service | What it is | Docs |
|---|---|---|
| [`odoo/`](odoo/) | ERP (multi-instance — run several isolated instances side by side) | [README](odoo/README.md) |
| [`openproject/`](openproject/) | Project management / issue tracking | [README](openproject/README.md) |
| [`nextcloud/`](nextcloud/) | File sync & sharing | [README](nextcloud/README.md) |
| [`n8n/`](n8n/) | Workflow automation | [README](n8n/README.md) |

---

## 🚀 Quick Start

### 1. Install the core infrastructure first (if you haven't)

```bash
curl -fsSL -o install_docker_core.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/docker_installs/main/install_docker_core.sh
chmod +x install_docker_core.sh
sudo ./install_docker_core.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows.

### 2. Pick and deploy a service

Easiest way — run [`services.sh`](services.sh), which lists every service here and launches the one you pick:

```bash
curl -fsSL -o services.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/docker_installs/main/services/services.sh
chmod +x services.sh
./services.sh
```
No sibling service folders next to it (i.e. you didn't `git clone` the full repo)? It detects that automatically and downloads the service you pick fresh from GitHub instead.

Or run any service's `deploy.sh` directly — see that service's own README for its exact `curl` commands.

> ⚠️ **Do not run `services.sh` or any `deploy.sh` as root.** Your user must be in the `docker` group (set up by `install_docker_core.sh`).

---

## 📐 Convention Every Service Follows

- **Its own `.env`** — generated automatically by `deploy.sh` with random secrets (never committed; covered by the root [`.gitignore`](../.gitignore)), `chmod 600`.
- **Networking**: a private `<service>-net` for the service's own containers (app ↔ db, etc.), and only the app/entrypoint container also joins the shared external `main-net` so NPM can reach it by container name. Databases and internal-only containers never touch `main-net` and never publish a host port.
- **Naming**: containers are `<service>-app` / `<service>-db` (or descriptive names for additional containers in multi-container stacks, e.g. `openproject-worker`).
- **Runtime state**: lives under `~/docker/<service>/` on the host (not inside this repo checkout) — logs, generated `.env`, and secrets files all land there, so the whole host's state stays backupable as one `~/docker/` tree.
- **Reruns are safe**: `deploy.sh` never overwrites an existing `docker-compose.yml` at `~/docker/<service>/` (so manual edits survive) and reuses an existing `.env` without re-prompting.
- **Optional memory cap**: most services ask once (on first deploy) whether to cap the main container's memory, applied via a generated `docker-compose.override.yml`. Say no and it runs uncapped.
- **Optional direct host port**: most services also ask once whether to publish a host port for quick direct access without NPM (default: no). Choosing one also flips any HTTPS-only-assuming settings (secure cookies, forced redirects) to their plain-HTTP-safe equivalents automatically — otherwise the direct port would be inaccessible. See the relevant "Reverse Proxy" section in each service's README for exactly what changes.

---

## ➕ Adding a New Service

Copy [`_template/`](_template/) to `services/<name>/` and adapt `deploy.sh.template` and `docker-compose.template.yml` to the new service, following the conventions above. See [`services/odoo/deploy.sh`](odoo/deploy.sh) for a full-featured example (multi-instance, interactive secret generation) or [`services/nextcloud/deploy.sh`](nextcloud/deploy.sh) for a simpler single-instance one.

Don't guess at a new service's official Docker image, required environment variables, or ports — check that project's own official Docker/Compose documentation first.
