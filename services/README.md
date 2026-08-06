# 🧱 Services

Optional services that run on top of the core infrastructure ([`install_dockhub.sh`](../install_dockhub.sh) — Docker CE, Compose, NGINX Proxy Manager, Portainer, and the shared `main-net` network). Each one lives in its own folder here, is deployed independently, and you only run the ones you actually need.

---

## 📋 Services Roadmap

[`services.sh`](services.sh) presents these grouped by category. ✅ = deployable now, 🚧 = listed in the menu already (shows "coming soon" if picked) but not built yet.

| Category | Services |
|---|---|
| **AI** | 🚧 [![Ollama](https://img.shields.io/badge/Ollama-000000?style=flat-square&logo=ollama&logoColor=white)](AI/ollama/) · 🚧 <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/open-webui.svg" width="16" height="16" valign="middle"> [Open WebUI](AI/open-webui/) · 🚧 [![Dify](https://img.shields.io/badge/Dify-0033FF?style=flat-square&logo=dify&logoColor=white)](AI/dify/) · 🚧 <img src="https://llama-cpp.com/wp-content/uploads/2025/10/Llama-cpp-300x108.jpg" height="16" valign="middle"> [llama.cpp](AI/llama-cpp/) · 🚧 <img src="https://localai.io/img/logo-mark.png" height="16" valign="middle"> [LocalAI](AI/localai/) · 🚧 <img src="https://paperclip.ing/favicon.svg" width="16" height="16" valign="middle"> [Paperclip](AI/paperclip/) (deliberately deferred — no pre-built image upstream, see its README) |
| **Automation** | ✅ [![n8n](https://img.shields.io/badge/n8n-EA4B71?style=flat-square&logo=n8n&logoColor=white)](Automation/n8n/) · 🚧 <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/openclaw.svg" width="16" height="16" valign="middle"> [OpenClaw](Automation/openclaw/) · 🚧 <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/hermes-icon.svg" width="16" height="16" valign="middle"> [Hermes](Automation/hermes/) |
| **DNS** | ✅ [![Pi-hole](https://img.shields.io/badge/Pi--hole-96060C?style=flat-square&logo=pihole&logoColor=white)](DNS/pi-hole/) · ✅ [![AdGuard](https://img.shields.io/badge/AdGuard-68BC71?style=flat-square&logo=adguard&logoColor=white)](DNS/adguard/) |
| **ERP** | 🚧 [![ERPNext](https://img.shields.io/badge/ERPNext-0089FF?style=flat-square&logo=erpnext&logoColor=white)](ERP/erpnext/) · 🚧 [![Dolibarr](https://img.shields.io/badge/Dolibarr-263C5C?style=flat-square&logo=dolibarr&logoColor=white)](ERP/dolibarr/) · ✅ [![Odoo](https://img.shields.io/badge/Odoo-714B67?style=flat-square&logo=odoo&logoColor=white)](ERP/odoo/) (multi-instance) |
| **Home-Automation** | ✅ [![Home Assistant](https://img.shields.io/badge/Home_Assistant-18BCF2?style=flat-square&logo=homeassistant&logoColor=white)](Home-Automation/home-assistant/) · 🚧 [![Zigbee2MQTT](https://img.shields.io/badge/Zigbee2MQTT-FFC135?style=flat-square&logo=zigbee2mqtt&logoColor=white)](Home-Automation/zigbee2mqtt/) · 🚧 [![Eclipse Mosquitto](https://img.shields.io/badge/Eclipse_Mosquitto-3C5280?style=flat-square&logo=eclipsemosquitto&logoColor=white)](Home-Automation/mosquitto/) |
| **Media** | ✅ [![Jellyfin](https://img.shields.io/badge/Jellyfin-00A4DC?style=flat-square&logo=jellyfin&logoColor=white)](Media/jellyfin/) · 🚧 [![Plex](https://img.shields.io/badge/Plex-EBAF00?style=flat-square&logo=plex&logoColor=white)](Media/plex/) |
| **Photos** | ✅ [![Immich](https://img.shields.io/badge/Immich-4250AF?style=flat-square&logo=immich&logoColor=white)](Photos/immich/) · 🚧 <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/photoprism.svg" width="16" height="16" valign="middle"> [PhotoPrism](Photos/photoprism/) |
| **Projects** | ✅ [![OpenProject](https://img.shields.io/badge/OpenProject-0770B8?style=flat-square&logo=openproject&logoColor=white)](Projects/openproject/) · ✅ [![Plane](https://img.shields.io/badge/Plane-121212?style=flat-square&logo=plane&logoColor=white)](Projects/plane/) · ✅ [![Vikunja](https://img.shields.io/badge/Vikunja-196AFF?style=flat-square&logo=vikunja&logoColor=white)](Projects/vikunja/) · ✅ [![Redmine](https://img.shields.io/badge/Redmine-B32024?style=flat-square&logo=redmine&logoColor=white)](Projects/redmine/) · ✅ <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/taiga.svg" width="16" height="16" valign="middle"> [Taiga](Projects/taiga/) |
| **Security** | 🚧 [![Vaultwarden](https://img.shields.io/badge/Vaultwarden-000000?style=flat-square&logo=vaultwarden&logoColor=white)](Security/vaultwarden/) · 🚧 [![Authentik](https://img.shields.io/badge/Authentik-FD4B2D?style=flat-square&logo=authentik&logoColor=white)](Security/authentik/) · 🚧 [![Keycloak](https://img.shields.io/badge/Keycloak-4D4D4D?style=flat-square&logo=keycloak&logoColor=white)](Security/keycloak/) |
| **Storage** | ✅ [![Nextcloud](https://img.shields.io/badge/Nextcloud-0082C9?style=flat-square&logo=nextcloud&logoColor=white)](Storage/nextcloud/) · 🚧 [![Seafile](https://img.shields.io/badge/Seafile-FF9800?style=flat-square&logo=seafile&logoColor=white)](Storage/seafile/) · 🚧 [![ownCloud](https://img.shields.io/badge/ownCloud-041E42?style=flat-square&logo=owncloud&logoColor=white)](Storage/owncloud/) |
| **VPN** | ✅ [![WireGuard](https://img.shields.io/badge/WireGuard-88171A?style=flat-square&logo=wireguard&logoColor=white)](VPN/wireguard/) · 🚧 <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/headscale.svg" width="16" height="16" valign="middle"> [Headscale](VPN/headscale/) · 🚧 <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/netbird.svg" width="16" height="16" valign="middle"> [NetBird](VPN/netbird/) · 🚧 [![OpenVPN](https://img.shields.io/badge/OpenVPN-EA7E20?style=flat-square&logo=openvpn&logoColor=white)](VPN/openvpn/) |
| **Web** | ✅ [![WordPress](https://img.shields.io/badge/WordPress-21759B?style=flat-square&logo=wordpress&logoColor=white)](Web/wordpress/) · 🚧 [![Ghost](https://img.shields.io/badge/Ghost-15171A?style=flat-square&logo=ghost&logoColor=white)](Web/ghost/) · ✅ <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/linkstack.svg" width="16" height="16" valign="middle"> [LinkStack](Web/linkstack/) (multi-instance) |

Icons are pulled live (no local image files to maintain) from three sources: well-known brands get a colored badge from [Simple Icons](https://simpleicons.org/) via [shields.io](https://shields.io/); niche self-hosted-specific apps get a plain icon from [dashboard-icons](https://github.com/homarr-labs/dashboard-icons) (the icon set used by Homarr/Homepage dashboards) via jsDelivr; llama.cpp and LocalAI (in neither set) link directly to their own official logo assets.

This is the project roadmap, not a promise of order — services get built one at a time. The category/service list itself lives in [`services.sh`](services.sh)'s `CATALOG` array; a service becomes ✅ automatically the moment its `services/<Category>/<slug>/deploy.sh` exists, no separate flag to flip.

---

## 🔌 Suggested Default Ports

Only relevant if you opt into a service's **direct host port** prompt (default is no host port at all — NPM reaches every service by container name). Listed so you can mentally track what's in use before deploying several services at once; each `deploy.sh` still lets you type any port you want at the prompt.

| Service | Suggested port |
|---|---|
| Odoo | `8069` (+ `8072` for WebSocket/longpolling) |
| OpenProject | `8080` |
| Nextcloud | `8080` ⚠️ same suggested default as OpenProject — pick a different one if running both |
| n8n | `5678` |
| Redmine | `3000` |
| Taiga | `9000` |
| Vikunja | `3456` |
| Plane | `8090` |
| LinkStack | `8095` (suggested for each instance — multi-instance, pick a different port per instance if publishing more than one) |
| Jellyfin | `8096` |
| Home Assistant | `8123` — **always** bound to the host (host networking, not an opt-in prompt like the others above) |
| Immich | `2283` |
| Pi-hole | Web UI `8081` (optional, deliberately not `80` — NPM owns that already). DNS itself (`53`) is **always** bound to the host, not an opt-in prompt — see its README for the systemd-resolved conflict almost every Ubuntu server has out of the box. |
| WireGuard (wg-easy) | Web UI `51821` (optional). The VPN data port (`51820/udp`) is **always** bound to the host, not an opt-in prompt — same reasoning as Pi-hole's DNS port. |
| WordPress | `8082` ⚠️ deliberately not `8080` (upstream's own default) — already taken by OpenProject/Nextcloud's suggested defaults above |
| AdGuard Home | Setup wizard `3000`, admin UI `80` (both optional together). DNS itself (`53`) is **always** bound to the host, not an opt-in prompt — same reasoning as Pi-hole's DNS port. |

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
4) Backup
5) Restore from backup
0) Back
```

- **Deploy / manage** just runs that service's `deploy.sh` — safe to pick whether it's a fresh install or an existing one (reuses `.env`, won't overwrite `docker-compose.yml`).
- **Remove** stops its containers and asks separately whether to also permanently delete its data (database, uploaded files, secrets). Say no and only the containers/cached compose file go — `.env` and volumes are kept so a later deploy picks up right where you left off.
- **Reinstall** does Remove, then immediately deploys fresh. For multi-instance services (odoo), picking Remove or Reinstall with more than one instance deployed asks which instance first.
- **Backup** saves the entire `~/docker/<service>/` directory (`.env`, compose files, and any bind-mounted data like Vikunja's `files/` or Redmine's `plugins/`/`themes/`) plus every named Docker volume, to `~/docker/backups/<service>/[<instance>/]<timestamp>.tar.gz` — you can create as many as you want, nothing is ever auto-deleted. Services with a separate database container (Postgres/MySQL) additionally use a proper `pg_dump`/`mysqldump` for the database itself instead of copying its live data files, if that service ships a `backup.sh` (see [`services/_template/`](_template/)) — otherwise the database volume just gets tarred as-is (fine for config-only/SQLite-embedded services like Jellyfin/LinkStack, which have no separate database at all).
- **Restore from backup** lists your saved backups (newest first), confirms before overwriting current data, restores, and restarts the service.

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
- **Shared logic lives in [`lib/common.sh`](../lib/common.sh)**, not copy-pasted per service — `prompt_mem_limit`, `prompt_host_port`, `generate_secret`, `ensure_main_net`, backup/restore, and the environment-detection reader all come from there. Every `deploy.sh` sources it (self-fetching a copy via `curl` first if run standalone, so a bare `curl deploy.sh && bash deploy.sh` still works with no extra steps). Never redefine these functions locally in a new service's `deploy.sh`.

> ⚠️ **Using Cloudflare Tunnel instead of a normal DNS A/AAAA record?** This applies to every service here, not just one — full guide: [docs/cloudflare-tunnel.md](../docs/cloudflare-tunnel.md). Short version: `cloudflared` delivers traffic to NPM over plain HTTP by design (Cloudflare's edge already terminates HTTPS for the visitor); leaving **Force SSL off** on the Proxy Host avoids a redirect loop that otherwise surfaces as `400 Bad Request — Request Header Or Cookie Too Large`. Not a security downgrade — Cloudflare's edge still enforces HTTPS to every visitor regardless. Other network/reverse-proxy issues: [docs/troubleshooting.md](../docs/troubleshooting.md).

---

## ➕ Adding a New Service

1. Pick the category it belongs to (see the roadmap table above, or `services.sh`'s `CATALOG` array), then copy [`_template/`](_template/) to `services/<Category>/<slug>/` and adapt `deploy.sh.template` and `docker-compose.template.yml` to the new service, following the conventions above. See [`services/ERP/odoo/deploy.sh`](ERP/odoo/deploy.sh) for a full-featured example (multi-instance, interactive secret generation) or [`services/Storage/nextcloud/deploy.sh`](Storage/nextcloud/deploy.sh) for a simpler single-instance one.
2. Add `[<slug>]="docker-compose.yml ..."` to `services.sh`'s `SERVICE_FILES` table, listing every file besides `deploy.sh` the service needs (keep in sync with that service's own README "Installation" curl commands).
3. If `<slug>` isn't already in `services.sh`'s `CATALOG` array as a `🚧` placeholder, add it there too (`Category|slug|Display Name`) — otherwise it's already there and just flips to ✅ automatically. `Category` here must exactly match the folder name from step 1.
4. If the service has a separate database container (Postgres/MySQL), define `backup_<slug>()`/`restore_<slug>()` in its `deploy.sh` — see the commented-out example at the bottom of `deploy.sh.template`. Otherwise skip this; the generic volume-based backup in `lib/common.sh` is picked up automatically.

Don't guess at a new service's official Docker image, required environment variables, or ports — check that project's own official Docker/Compose documentation first.
