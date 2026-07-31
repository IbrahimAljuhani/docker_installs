# 🧱 Services

Optional services that run on top of the core infrastructure ([`install_docker_core.sh`](../install_docker_core.sh) — Docker CE, Compose, NGINX Proxy Manager, Portainer, and the shared `main-net` network). Each one lives in its own folder here, is deployed independently, and you only run the ones you actually need.

---

## 📋 Available Services

| Service | What it is | Docs |
|---|---|---|
| [`odoo/`](odoo/) | ERP (multi-instance — run several isolated instances side by side) | [README](odoo/README.md) |
| [`openproject/`](openproject/) | Project management / issue tracking | [README](openproject/README.md) |
| [`redmine/`](redmine/) | Project management / issue tracking (lighter-weight alternative to OpenProject) | [README](redmine/README.md) |
| [`taiga/`](taiga/) | Agile/kanban project management | [README](taiga/README.md) |
| [`nextcloud/`](nextcloud/) | File sync & sharing | [README](nextcloud/README.md) |
| [`n8n/`](n8n/) | Workflow automation | [README](n8n/README.md) |

---

## 🚀 Quick Start

### 1. Clone the repo and install the core infrastructure (if you haven't)

```bash
git clone https://github.com/IbrahimAljuhani/docker_installs.git
cd docker_installs
sudo bash install_docker_core.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows.

### 2. Pick and deploy a service

Pick **`2) Install a service`** from that same menu — it launches [`services.sh`](services.sh) right there, which lists every service here and, once you pick one, gives you:

```
1) Deploy / manage (runs deploy.sh — safe for new or existing deployments)
2) Remove
3) Reinstall (remove, then deploy fresh)
4) Back
```

- **Deploy / manage** just runs that service's `deploy.sh` — safe to pick whether it's a fresh install or an existing one (reuses `.env`, won't overwrite `docker-compose.yml`).
- **Remove** stops its containers and asks separately whether to also permanently delete its data (database, uploaded files, secrets). Say no and only the containers/cached compose file go — `.env` and volumes are kept so a later deploy picks up right where you left off.
- **Reinstall** does Remove, then immediately deploys fresh. For multi-instance services (odoo), picking Remove or Reinstall with more than one instance deployed asks which instance first.

Or run `bash services/services.sh` (or `bash deploy.sh` inside any service's own folder, see that service's own README) yourself at any time.

> 💡 **Didn't clone the repo** (just curled `install_docker_core.sh` alone)? "Install a service" still works — `services.sh` detects there's no local checkout and downloads the service you pick fresh from GitHub instead. See [`services.sh`](services.sh) usage in that case: `curl -fsSL -o services.sh https://raw.githubusercontent.com/IbrahimAljuhani/docker_installs/main/services/services.sh && bash services.sh`.
>
> Everywhere in this repo, run scripts as `bash <file>` rather than `chmod +x <file> && ./<file>` — a fresh `git clone`/`git pull` doesn't reliably preserve the executable bit, and `bash <file>` works regardless of it.

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
