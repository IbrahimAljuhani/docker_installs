# 🧱 Services

Optional services that run on top of the core infrastructure ([`install_dockhub.sh`](../install_dockhub.sh) — Docker CE, Compose, NGINX Proxy Manager, Portainer, and the shared `main-net` network). Each one lives in its own folder here, is deployed independently, and you only run the ones you actually need.

---

## 📋 Services Roadmap

[`services.sh`](services.sh) presents these grouped by category. ✅ = deployable now, 🚧 = listed in the menu already (shows "coming soon" if picked) but not built yet.

| Category | Services |
|---|---|
| **AI** | 🚧 [Ollama](AI/ollama/) · 🚧 [Open WebUI](AI/open-webui/) · 🚧 [Dify](AI/dify/) · 🚧 [llama.cpp](AI/llama-cpp/) · 🚧 [LocalAI](AI/localai/) |
| **Automation** | ✅ [n8n](Automation/n8n/) · 🚧 [OpenClaw](Automation/openclaw/) · 🚧 [Hermes](Automation/hermes/) |
| **DNS** | 🚧 [Pi-hole](DNS/pi-hole/) · 🚧 [AdGuard](DNS/adguard/) |
| **ERP** | 🚧 [ERPNext](ERP/erpnext/) · 🚧 [Dolibarr](ERP/dolibarr/) · ✅ [Odoo](ERP/odoo/) (multi-instance) |
| **Home-Automation** | 🚧 [Home Assistant](Home-Automation/home-assistant/) · 🚧 [Zigbee2MQTT](Home-Automation/zigbee2mqtt/) · 🚧 [Eclipse Mosquitto](Home-Automation/mosquitto/) |
| **Media** | 🚧 [Jellyfin](Media/jellyfin/) · 🚧 [Plex](Media/plex/) |
| **Photos** | 🚧 [Immich](Photos/immich/) · 🚧 [PhotoPrism](Photos/photoprism/) |
| **Projects** | ✅ [OpenProject](Projects/openproject/) · ✅ [Plane](Projects/plane/) · ✅ [Vikunja](Projects/vikunja/) · ✅ [Redmine](Projects/redmine/) · ✅ [Taiga](Projects/taiga/) |
| **Security** | 🚧 [Vaultwarden](Security/vaultwarden/) · 🚧 [Authentik](Security/authentik/) · 🚧 [Keycloak](Security/keycloak/) |
| **Storage** | ✅ [Nextcloud](Storage/nextcloud/) · 🚧 [Seafile](Storage/seafile/) · 🚧 [ownCloud](Storage/owncloud/) |
| **VPN** | 🚧 [WireGuard](VPN/wireguard/) · 🚧 [Headscale](VPN/headscale/) · 🚧 [NetBird](VPN/netbird/) · 🚧 [OpenVPN](VPN/openvpn/) |
| **Web** | 🚧 [WordPress](Web/wordpress/) · 🚧 [Ghost](Web/ghost/) · 🚧 [Strapi](Web/strapi/) · 🚧 [LinkStack](Web/linkstack/) |

This is the project roadmap, not a promise of order — services get built one at a time. The category/service list itself lives in [`services.sh`](services.sh)'s `CATALOG` array; a service becomes ✅ automatically the moment its `services/<Category>/<slug>/deploy.sh` exists, no separate flag to flip.

---

## 🚀 Quick Start

### 1. Clone the repo and install the core infrastructure (if you haven't)

```bash
git clone https://github.com/IbrahimAljuhani/dockhub.git
cd dockhub
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows.

### 2. Pick and deploy a service

Pick **`2) Install a service`** from that same menu — it launches [`services.sh`](services.sh) right there. It's a two-level menu: pick a **category** (AI, Automation, ERP, Projects, ...), then a **service** within it. Services not built yet are shown too, marked `(coming soon)` — picking one just prints a notice and drops you back in that category's list instead of failing.

Pick an available (✅) service and you get:

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

> 💡 **Didn't clone the repo** (just curled `install_dockhub.sh` alone)? "Install a service" still works — `services.sh` detects there's no local checkout and downloads the service you pick fresh from GitHub instead. See [`services.sh`](services.sh) usage in that case: `curl -fsSL -o services.sh https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/services.sh && bash services.sh`.
>
> Everywhere in this repo, run scripts as `bash <file>` rather than `chmod +x <file> && ./<file>` — a fresh `git clone`/`git pull` doesn't reliably preserve the executable bit, and `bash <file>` works regardless of it.

> ⚠️ **Do not run `services.sh` or any `deploy.sh` as root.** Your user must be in the `docker` group (set up by `install_dockhub.sh`).

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

1. Pick the category it belongs to (see the roadmap table above, or `services.sh`'s `CATALOG` array), then copy [`_template/`](_template/) to `services/<Category>/<slug>/` and adapt `deploy.sh.template` and `docker-compose.template.yml` to the new service, following the conventions above. See [`services/ERP/odoo/deploy.sh`](ERP/odoo/deploy.sh) for a full-featured example (multi-instance, interactive secret generation) or [`services/Storage/nextcloud/deploy.sh`](Storage/nextcloud/deploy.sh) for a simpler single-instance one.
2. Add `[<slug>]="docker-compose.yml ..."` to `services.sh`'s `SERVICE_FILES` table, listing every file besides `deploy.sh` the service needs (keep in sync with that service's own README "Installation" curl commands).
3. If `<slug>` isn't already in `services.sh`'s `CATALOG` array as a `🚧` placeholder, add it there too (`Category|slug|Display Name`) — otherwise it's already there and just flips to ✅ automatically. `Category` here must exactly match the folder name from step 1.

Don't guess at a new service's official Docker image, required environment variables, or ports — check that project's own official Docker/Compose documentation first.
