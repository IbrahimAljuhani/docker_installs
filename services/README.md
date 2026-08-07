# 🧱 Services

Optional services that run on top of the core infrastructure ([`install_dockhub.sh`](../install_dockhub.sh) — Docker CE, Compose, NGINX Proxy Manager, Portainer, and the shared `main-net` network). Each one lives in its own folder here, is deployed independently, and you only run the ones you actually need.

---

## 📋 Services Roadmap

**18 of 39 services built — 46%**

`████████████░░░░░░░░░░░░░░` 46%

[`services.sh`](services.sh) presents these grouped by category. ✅ = deployable now, 🚧 = listed in the menu already (shows "coming soon" if picked) but not built yet.

> 💡 **Hover any icon to see its name**, click it to open that service's README.

| Category | Built | Services |
|---|---|---|
| **AI** | 0/6 | 🚧 <a href="AI/ollama/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/ollama.svg" width="24" height="24" alt="Ollama" title="Ollama"></a> · 🚧 <a href="AI/open-webui/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/open-webui.svg" width="24" height="24" alt="Open WebUI" title="Open WebUI"></a> · 🚧 <a href="AI/dify/"><img src="https://cdn.simpleicons.org/dify" width="24" height="24" alt="Dify" title="Dify"></a> · 🚧 <a href="AI/llama-cpp/"><img src="https://llama-cpp.com/wp-content/uploads/2025/10/Llama-cpp-300x108.jpg" height="24" alt="llama.cpp" title="llama.cpp"></a> · 🚧 <a href="AI/localai/"><img src="https://localai.io/img/logo-mark.png" height="24" alt="LocalAI" title="LocalAI"></a> · 🚧 <a href="AI/paperclip/"><img src="https://paperclip.ing/favicon.svg" width="24" height="24" alt="Paperclip" title="Paperclip — deferred, no pre-built image upstream"></a> |
| **Automation** | 1/3 | ✅ <a href="Automation/n8n/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/n8n.svg" width="24" height="24" alt="n8n" title="n8n"></a> · 🚧 <a href="Automation/openclaw/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/openclaw.svg" width="24" height="24" alt="OpenClaw" title="OpenClaw"></a> · 🚧 <a href="Automation/hermes/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/hermes-icon.svg" width="24" height="24" alt="Hermes" title="Hermes"></a> |
| **DNS** | 2/2 | ✅ <a href="DNS/pi-hole/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/pi-hole.svg" width="24" height="24" alt="Pi-hole" title="Pi-hole"></a> · ✅ <a href="DNS/adguard/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/adguard-home.svg" width="24" height="24" alt="AdGuard Home" title="AdGuard Home"></a> |
| **ERP** | 1/3 | 🚧 <a href="ERP/erpnext/"><img src="https://cdn.simpleicons.org/erpnext" width="24" height="24" alt="ERPNext" title="ERPNext"></a> · 🚧 <a href="ERP/dolibarr/"><img src="https://cdn.simpleicons.org/dolibarr" width="24" height="24" alt="Dolibarr" title="Dolibarr"></a> · ✅ <a href="ERP/odoo/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/odoo.svg" width="24" height="24" alt="Odoo" title="Odoo (multi-instance)"></a> |
| **Home-Automation** | 1/3 | ✅ <a href="Home-Automation/home-assistant/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/home-assistant.svg" width="24" height="24" alt="Home Assistant" title="Home Assistant"></a> · 🚧 <a href="Home-Automation/zigbee2mqtt/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/zigbee2mqtt.svg" width="24" height="24" alt="Zigbee2MQTT" title="Zigbee2MQTT"></a> · 🚧 <a href="Home-Automation/mosquitto/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/mosquitto.svg" width="24" height="24" alt="Eclipse Mosquitto" title="Eclipse Mosquitto"></a> |
| **Media** | 2/2 | ✅ <a href="Media/jellyfin/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/jellyfin.svg" width="24" height="24" alt="Jellyfin" title="Jellyfin"></a> · ✅ <a href="Media/plex/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/plex.svg" width="24" height="24" alt="Plex" title="Plex — proprietary, needs a Plex account"></a> |
| **Photos** | 2/2 | ✅ <a href="Photos/immich/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/immich.svg" width="24" height="24" alt="Immich" title="Immich"></a> · ✅ <a href="Photos/photoprism/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/photoprism.svg" width="24" height="24" alt="PhotoPrism" title="PhotoPrism"></a> |
| **Projects** | 5/5 | ✅ <a href="Projects/openproject/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/openproject.svg" width="24" height="24" alt="OpenProject" title="OpenProject"></a> · ✅ <a href="Projects/plane/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/plane.svg" width="24" height="24" alt="Plane" title="Plane"></a> · ✅ <a href="Projects/vikunja/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/vikunja.svg" width="24" height="24" alt="Vikunja" title="Vikunja"></a> · ✅ <a href="Projects/redmine/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/redmine.svg" width="24" height="24" alt="Redmine" title="Redmine"></a> · ✅ <a href="Projects/taiga/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/taiga.svg" width="24" height="24" alt="Taiga" title="Taiga"></a> |
| **Security** | 0/3 | 🚧 <a href="Security/vaultwarden/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/vaultwarden.svg" width="24" height="24" alt="Vaultwarden" title="Vaultwarden"></a> · 🚧 <a href="Security/authentik/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/authentik.svg" width="24" height="24" alt="Authentik" title="Authentik"></a> · 🚧 <a href="Security/keycloak/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/keycloak.svg" width="24" height="24" alt="Keycloak" title="Keycloak"></a> |
| **Storage** | 1/3 | ✅ <a href="Storage/nextcloud/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/nextcloud.svg" width="24" height="24" alt="Nextcloud" title="Nextcloud"></a> · 🚧 <a href="Storage/seafile/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/seafile.svg" width="24" height="24" alt="Seafile" title="Seafile"></a> · 🚧 <a href="Storage/owncloud/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/owncloud.svg" width="24" height="24" alt="ownCloud" title="ownCloud"></a> |
| **VPN** | 1/4 | ✅ <a href="VPN/wireguard/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/wireguard.svg" width="24" height="24" alt="WireGuard" title="WireGuard (via wg-easy)"></a> · 🚧 <a href="VPN/headscale/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/headscale.svg" width="24" height="24" alt="Headscale" title="Headscale"></a> · 🚧 <a href="VPN/netbird/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/netbird.svg" width="24" height="24" alt="NetBird" title="NetBird"></a> · 🚧 <a href="VPN/openvpn/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/openvpn.svg" width="24" height="24" alt="OpenVPN" title="OpenVPN"></a> |
| **Web** | 2/3 | ✅ <a href="Web/wordpress/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/wordpress.svg" width="24" height="24" alt="WordPress" title="WordPress"></a> · 🚧 <a href="Web/ghost/"><img src="https://cdn.simpleicons.org/ghost" width="24" height="24" alt="Ghost" title="Ghost"></a> · ✅ <a href="Web/linkstack/"><img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/linkstack.svg" width="24" height="24" alt="LinkStack" title="LinkStack (multi-instance)"></a> |

Icons are pulled live (no local image files to maintain), mostly from [dashboard-icons](https://github.com/homarr-labs/dashboard-icons) — the icon set used by Homarr/Homepage dashboards — via jsDelivr. The four it doesn't carry (Dify, ERPNext, Dolibarr, Ghost) come from [Simple Icons](https://simpleicons.org/)' CDN, and llama.cpp / LocalAI / Paperclip link straight to their own official logo assets.

This is the project roadmap, not a promise of order — services get built one at a time. The category/service list itself lives in [`services.sh`](services.sh)'s `CATALOG` array; a service becomes ✅ automatically the moment its `services/<Category>/<slug>/deploy.sh` exists, no separate flag to flip. **The counts above are maintained by hand — update them when you add a service.**

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
| Plex | `32400` |
| PhotoPrism | `2342` |

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
