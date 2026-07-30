# 🗂️ OpenProject

Deploys the official [OpenProject](https://www.openproject.org/) stack — a project management / issue tracking tool — behind the shared `main-net` network so [NGINX Proxy Manager](../../README.md) can front it.

Adapted from the official [opf/openproject-docker-compose](https://github.com/opf/openproject-docker-compose) (`stable/17` branch). See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from upstream (their bundled Caddy proxy and `autoheal` are dropped since NPM already fills that role in this framework).

> ⚠️ **Resource requirements**: OpenProject needs **at least 4 GB RAM / 2 CPU cores / 20 GB disk** for a small team (10–20 users) — significantly heavier than the other services in this repo. Check your host has room before deploying. ([source](https://www.openproject.org/docs/installation-and-operations/system-requirements/))

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_docker_core.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/docker_installs/main/install_docker_core.sh
chmod +x install_docker_core.sh
sudo ./install_docker_core.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy OpenProject

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/docker_installs/main/services/openproject/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/docker_installs/main/services/openproject/docker-compose.yml
chmod +x deploy.sh
./deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group (the same requirement as `services/odoo`).

You'll be prompted once for the public domain you plan to point NPM at (e.g. `openproject.example.com`). Everything else — `POSTGRES_PASSWORD`, `SECRET_KEY_BASE` (Rails secret), `COLLABORATIVE_SERVER_SECRET` — is generated automatically and saved to `.env` (`600`) and a one-time readable copy at `~/docker/openproject/.openproject-docker-secrets.txt` (`600`).

This is a **single-instance** service (unlike `services/odoo`, which supports multiple named instances) — one OpenProject deployment per host, under `~/docker/openproject/`.

You'll also be asked whether to cap memory on the `web` container (default suggestion: `2g`; `db`/`worker`/`cron`/`seeder`/`hocuspocus` stay unbounded either way). Say no and it runs uncapped. This choice, like the domain and secrets, is only asked once — rerunning `deploy.sh` reuses `.env` and **never overwrites an existing `docker-compose.yml`** at `~/docker/openproject/` (so any manual edits you make there survive reruns; delete it yourself first if you want the latest version from this repo).

> 💡 **To change the memory limit later**: edit `MEM_LIMIT=` in `~/docker/openproject/.env` (change the value, or delete the line entirely to remove the cap), then rerun `deploy.sh` — it regenerates `docker-compose.override.yml` from whatever `.env` currently has and reapplies it with `docker compose up -d`.

You'll also be asked whether to publish a host port for direct access without NPM (e.g. `http://<server-ip>:8080`) — useful for a quick first check that the container actually works before wiring up NPM. Default is no. Say yes and the port is checked for conflicts, then printed as a URL once OpenProject starts.

Choosing a host port also sets `OPENPROJECT_HTTPS=false` in `.env` automatically — with it `true` (the default when you *don't* choose a host port), OpenProject force-redirects to `https://` and marks cookies secure-only, which makes a bare `http://` direct port completely inaccessible. The one thing that still doesn't work over the direct port regardless: `/hocuspocus` real-time collaborative editing needs NPM's path routing. Once you switch to NPM+SSL, edit `OPENPROJECT_HTTPS=true` (and remove `HOST_PORT=` if you no longer want the direct port) in `.env` and rerun `deploy.sh`.

First startup takes a few minutes: the `seeder` container runs database migrations and creates the default admin user before `web`/`worker`/`cron` can do anything useful.

---

## 👤 First Login

- **Username**: `admin`
- **Password**: `admin`

You'll be **forced to change it immediately** on first login — this is OpenProject's own built-in behavior, not something this script configures.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

OpenProject needs **two proxy targets** on the same domain — the main app, and the real-time/collaborative-editing websocket (`hocuspocus`) at a specific path:

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: the same domain you entered during `deploy.sh` (must match `OPENPROJECT_HOST__NAME` in `.env`)
   - **Forward Hostname/IP**: `openproject-app`
   - **Forward Port**: `8080`
   - Enable **Websockets Support**
3. On the **Advanced** tab, route `/hocuspocus` to the collaborative-editing server:
   ```nginx
   location /hocuspocus {
       proxy_pass http://openproject-hocuspocus:1234;
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
   }
   ```
4. Enable **SSL** with Let's Encrypt from the UI.

✅ No host ports are published for `web` or `hocuspocus` — NPM reaches both by container name over `main-net`, matching the reverse-proxy convention used everywhere else in this repo.

---

## 🛠️ Management Commands

```bash
cd ~/docker/openproject
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status (8 containers: db, cache, web, worker, cron, seeder, hocuspocus) |
| `docker compose logs -f web` | Follow the main app's logs |
| `docker compose logs -f seeder` | Check migration/seed progress on first run |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest image for the pinned `TAG` |

---

## 📌 Known Simplifications vs. Upstream

- `proxy` (Caddy) and `autoheal` containers are **not deployed** — NPM replaces the former; the latter needs a `docker.sock` mount not worth the extra attack surface for a first pass. Re-add `autoheal` yourself later if you want automatic container restarts on failed healthchecks.
- A few secondary tuning variables upstream sets explicitly (`OPENPROJECT_HSTS`, `IMAP_ENABLED`, `RAILS_MIN_THREADS`/`RAILS_MAX_THREADS`, `OPENPROJECT_ADDITIONAL__HOST__NAMES`) are left unset here and fall back to the image's own internal defaults, rather than being re-pinned to upstream's specific values. Functionally fine for a first deployment; revisit if you need to harden HSTS explicitly or tune worker thread counts for your load.

---

## 📜 License

OpenProject itself is licensed separately by the OpenProject GmbH — see the [official repository](https://github.com/opf/openproject) for terms. This deployment wrapper follows the same [MIT license](../../LICENSE) as the rest of this repo.
