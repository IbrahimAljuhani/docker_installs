# 🎬 Jellyfin

Deploys [Jellyfin](https://jellyfin.org/) (a free, open-source media server — movies, TV, music) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

Adapted from the [official Docker installation guide](https://jellyfin.org/docs/general/installation/container/). See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from upstream.

Like LinkStack, Jellyfin is a **single container** — no separate database (its config/metadata live in a Docker volume, SQLite-based internally).

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy Jellyfin

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Media/jellyfin/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Media/jellyfin/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service: one Jellyfin deployment per host, under `~/docker/jellyfin/`.

You'll be asked for your **media library path** on the host — this is required, unlike every other prompt below, and it's two separate questions:
1. Whether you already have a media folder, or want one created fresh.
2. The path itself — if creating fresh, `deploy.sh` runs `mkdir -p` on it right there (and tells you exactly why if that fails, e.g. no write permission — try a path under `$HOME`, or create it yourself first with `sudo mkdir -p <path> && sudo chown $USER <path>`); if pointing at an existing folder, it's validated to actually exist.

Either way it's mounted read-only into the container at `/media`.

You'll also be asked whether to cap memory on the `jellyfin` container (default suggestion: `2g` — transcoding is memory-hungry). Say no and it runs uncapped.

> 💡 **To change the memory limit later**: edit `MEM_LIMIT=` in `~/docker/jellyfin/.env`, then rerun `deploy.sh` — it regenerates `docker-compose.override.yml` from whatever `.env` currently has and reapplies it with `docker compose up -d`.

You'll also be asked whether to publish a host port for direct access without NPM (e.g. `http://<server-ip>:8096`) — useful for a quick first check, or for LAN clients (smart TVs, etc.) that expect to reach Jellyfin directly. Default is no.

If `deploy.sh` detects `/dev/dri` on the host (an Intel/AMD GPU render device), it asks whether to enable **hardware transcoding passthrough**. Default is no — most servers don't have a compatible GPU, and Jellyfin works fine with software (CPU) transcoding, just slower under load.

Either way, these choices are only asked once — rerunning `deploy.sh` reuses `.env` and **never overwrites an existing `docker-compose.yml`** at `~/docker/jellyfin/` (so any manual edits you make there survive reruns; delete it yourself first if you want the latest version from this repo).

---

## 👤 First Login

Jellyfin has **no default admin account**. Visiting the site for the first time runs its own setup wizard: choose a display language, create your admin account, and (optionally) point it at your media library — since `/media` is already mounted, just add it as a library folder inside the wizard.

---

## ⚠️ Required: Set "Known Proxies" After First Login

By default, Jellyfin **discards** `X-Forwarded-For` unless it comes from an IP it's told to trust — otherwise every visitor shows up in logs/sessions as NPM's own container IP instead of their real one, per [Jellyfin's own reverse-proxy docs](https://jellyfin.org/docs/general/post-install/networking/reverse-proxy/).

1. Find `main-net`'s subnet:
   ```bash
   docker network inspect main-net --format '{{ (index .IPAM.Config 0).Subnet }}'
   ```
2. In Jellyfin: **Admin Dashboard → Networking → Known proxies** → add that subnet (e.g. `172.20.0.0/16`) → **Save**.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: the domain you want to use (e.g. `jellyfin.example.com`)
   - **Forward Hostname/IP**: `jellyfin-app`
   - **Forward Port**: `8096`
   - **Websockets Support**: **enabled** — Jellyfin uses WebSockets for sync/notifications/now-playing; without this, some features silently break.
3. Enable **SSL** with Let's Encrypt from the UI.

> 💻 **Using Cloudflare Tunnel instead of a normal DNS record?** See the Cloudflare Tunnel note in [services/README.md](../../README.md#-convention-every-service-follows) — leave **Force SSL** off on this Proxy Host, or you'll hit a redirect-loop / "Request Header Or Cookie Too Large" error.

✅ No host port is published for `jellyfin-app` by default — NPM reaches it by container name over `main-net`.

---

## 🛠️ Management Commands

```bash
cd ~/docker/jellyfin
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f jellyfin` | Follow the app's logs |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest image |

Jellyfin also shows update notifications in its own Admin Dashboard, but (unlike LinkStack) has no in-app one-click updater for the Docker image — use the commands above.

---

## 📌 Known Simplifications vs. Upstream

- No private `<service>-net` — like LinkStack, Jellyfin has nothing to isolate (one container, no database container), so `jellyfin-app` joins `main-net` directly.
- Media is mounted **read-only** (`:ro`). If you want Jellyfin to save local `.nfo` metadata/images alongside your media files (an opt-in Jellyfin feature, off by default), edit the mount in `~/docker/jellyfin/docker-compose.yml` to drop `:ro` yourself — not exposed as a prompt here since most people don't need it.
- Only `/dev/dri` (Intel/AMD VAAPI/QSV) hardware transcoding is offered as an opt-in prompt. NVIDIA GPU passthrough (via `nvidia-container-toolkit`) needs additional host setup this repo doesn't automate — see [Jellyfin's hardware acceleration docs](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/) if you need it.
- DLNA/local-network auto-discovery (UDP port 7359, and SSDP) isn't published — it needs `network_mode: host` to work properly, which would conflict with this repo's `main-net`-only convention. Discovery-dependent clients (some smart TV apps) may need the server URL entered manually instead of relying on auto-discovery.

---

## 📜 License

Jellyfin itself is licensed separately (GPL-2.0 — see the [official repository](https://github.com/jellyfin/jellyfin) for terms). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
