# 📊 ERPNext

Deploys [ERPNext](https://erpnext.com/) (a full open-source ERP — accounting, inventory, HR, manufacturing, CRM) on the [Frappe framework](https://frappeframework.com/), behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

Adapted from Frappe's own [`frappe_docker`](https://github.com/frappe/frappe_docker) — its `compose.yaml` plus the single-file `pwd.yml`. See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from upstream.

---

## ⚠️ Read This Before Deploying

**1. This is the heaviest service in this repo — 11 containers.**

| Container | Role |
|---|---|
| `erpnext-configurator` | One-shot: writes the db/redis connection config |
| `erpnext-create-site` | One-shot: runs `bench new-site`, installs the erpnext app |
| `erpnext-backend` | The Python app server (gunicorn) |
| `erpnext-frontend` | nginx — static assets, routes to backend/websocket |
| `erpnext-websocket` | Node.js socket.io, real-time UI updates |
| `erpnext-queue-short` | Background worker (short + default queues) |
| `erpnext-queue-long` | Background worker (long + default + short) |
| `erpnext-scheduler` | Scheduled/cron jobs |
| `erpnext-db` | MariaDB |
| `erpnext-redis-cache` | Cache |
| `erpnext-redis-queue` | Job queue + socket.io pub/sub |

None are optional — Frappe genuinely splits the work this way. Budget **4 GB RAM minimum**, 8 GB to be comfortable. First-run site creation compiles assets and takes **5–15 minutes**; `deploy.sh` waits for it and reports progress rather than claiming success early.

**2. The site is named after your domain, and that's not cosmetic.**

Frappe is multi-tenant: it decides *which site to serve* from the HTTP `Host` header. So a site must be **named** after the domain it's reached at. Serve a site named `erp.example.com` at `erp.other.com` and you get **"Site not found"** — the stack is healthy, it just doesn't recognise the name.

This is why the domain question during `deploy.sh` is unconditional, unlike most services here where it's tied to whether you want a host port.

> 💡 **You can still reach it by IP:port.** Upstream leaves `FRAPPE_SITE_NAME_HEADER` at `$host` (resolve strictly by Host header); this deployment pins it to the site name instead, so a direct `http://<server-ip>:8085` serves the same site rather than 404-ing. The trade is that this is single-site by design — which it is here anyway.

### Just trying it out, with no domain?

Answer the domain question with your **server's LAN IP** (e.g. `10.0.0.27`) and say yes to the host port. Frappe accepts an IP as a site name — upstream's own docs use `127.0.0.1` for local debugging — and `deploy.sh` adjusts accordingly: `host_name` becomes `http://10.0.0.27:8085` instead of an `https://` URL the site doesn't serve, and it skips the NPM instructions rather than printing a route that wouldn't work.

> ⚠️ **An IP-named site is LAN-only, and switching to a domain later means renaming the site** — the site directory and its database are named after the IP, and Frappe matches the Host header against that name. Renaming is a manual `bench` operation. If you already know the domain you'll use, enter it now even if DNS isn't pointing at the server yet; nothing about site creation requires the domain to resolve.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows.

### 2. Deploy ERPNext

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/ERP/erpnext/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/ERP/erpnext/docker-compose.yml
curl -fsSL -o backup.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/ERP/erpnext/backup.sh
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service (unlike [Odoo](../odoo/), which supports multiple named instances) — one ERPNext deployment per host, under `~/docker/erpnext/`.

You'll be asked for:

| Question | Notes |
|---|---|
| **Site domain** | Required, and becomes the site's name. See above. |
| Memory limit | Optional, suggested `2g`, applied to `erpnext-backend` only. |
| Host port | Optional, default `8085` → the frontend's `8080`. |

`deploy.sh` generates the MariaDB root password and the ERPNext Administrator password, saving them to `.env` (`600`) and a readable copy at `~/docker/erpnext/.erpnext-docker-secrets.txt` (`600`).

Rerunning `deploy.sh` is safe: it reuses `.env`, and the `create-site` container sees the site already exists and exits without touching it.

---

## 👤 First Login

Username **`Administrator`**, password from the secrets file:

```bash
cat ~/docker/erpnext/.erpnext-docker-secrets.txt
```

ERPNext then runs its own setup wizard on first login — company name, currency, fiscal year, chart of accounts.

> 📌 The login is `Administrator` with a capital A. It is not an email address, and it is not `admin`.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: the same domain you gave `deploy.sh` — this must match, see above
   - **Forward Hostname/IP**: `erpnext-frontend`
   - **Forward Port**: `8080`
   - Enable **Websockets Support** ← required; real-time updates use socket.io
3. Enable **SSL** with Let's Encrypt from the UI.

Scheme stays `http` — the frontend container serves plain HTTP, and NPM terminates TLS.

No custom nginx block is needed. Upload size (`50m`) and proxy timeout (`120s`) are already set on the frontend container itself; raise them in `docker-compose.yml` if you attach large files.

✅ No host port is published by default — NPM reaches `erpnext-frontend` by container name over `main-net`. Everything else stays on the private `erpnext-net`.

---

## 🩺 "Site not found" / blank page

Almost always the Host header not matching the site name. Check what sites actually exist:

```bash
docker exec erpnext-backend ls sites
```

You should see a directory named exactly like your domain. Then confirm what the frontend was told to look for:

```bash
docker exec erpnext-frontend env | grep FRAPPE_SITE_NAME_HEADER
```

Those two must be identical. If they aren't, fix `SITE_NAME` in `~/docker/erpnext/.env` and rerun `deploy.sh`.

> ⚠️ **Changing the domain after the site is created is not just an `.env` edit** — the site directory and its database are named after the old domain. Renaming a Frappe site is a manual `bench` operation; for a fresh deployment it is far quicker to remove and redeploy (services.sh → **Reinstall**) than to rename.

If the site directory doesn't exist at all, site creation failed or is still running:

```bash
cd ~/docker/erpnext && docker compose logs create-site
```

---

## 🛠️ Management Commands

```bash
cd ~/docker/erpnext
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Status of all 11 containers |
| `docker compose logs -f backend` | Follow the app server's logs |
| `docker compose logs -f create-site` | First-run site creation progress |
| `docker compose logs -f queue-long` | Background job failures show up here |
| `docker compose pull && docker compose up -d` | Update to the image tag in `.env` |

Frappe's own CLI, `bench`, runs inside the backend container:

```bash
docker exec erpnext-backend bench --site <your-domain> list-apps
```

```bash
docker exec erpnext-backend bench --site <your-domain> set-admin-password <new-password>
```

> 💡 **Upgrading ERPNext** is not just a `docker compose pull` — a new image usually ships schema changes that need `bench migrate` afterwards. Bump `ERPNEXT_VERSION` in `.env`, `docker compose up -d`, then run `docker exec erpnext-backend bench --site <your-domain> migrate`. Take a backup first.

---

## 💾 Backups

This service ships a DB-aware [`backup.sh`](backup.sh), so the **Backup** option in `services.sh` dumps MariaDB properly instead of raw-copying live database files. Two ERPNext-specific details it handles:

- **`--all-databases`**, because Frappe names a site's database after a generated hash, and creates a per-site DB user that lives in the `mysql` system database. Dumping only the site database would restore the data but not the account allowed to read it.
- **MariaDB 11 renamed the client binaries** (`mysqldump` → `mariadb-dump`); it tries the new name first and falls back.

The `sites` volume — site config, uploaded files, and the site's **encryption key** — is captured by the same run.

⚠️ That encryption key protects stored passwords and API secrets. A database restored **without** the matching `sites` volume leaves those fields unreadable, so always keep the two halves of a backup together.

> 💡 Frappe also has its own `bench --site <domain> backup --with-files`, which writes into `sites/<domain>/private/backups/`. It's the right tool if you want a Frappe-native archive to hand to another Frappe host; the repo's backup covers the whole deployment instead.

---

## 📌 Notes & Deviations

- **Generated passwords.** Upstream's `pwd.yml` hardcodes `admin` for both the MariaDB root password and the Administrator password. Both are generated here.
- **`FRAPPE_SITE_NAME_HEADER` pinned to the site name**, not upstream's `$host` default — see above. Costs multi-site, buys one less way to fail.
- **`UPSTREAM_REAL_IP_ADDRESS` is discovered, not hardcoded.** `deploy.sh` reads `main-net`'s actual subnet so nginx trusts NPM's `X-Forwarded-For`. Left at upstream's `127.0.0.1` default, every login record and audit-log entry in the ERP would show NPM's container IP instead of the real user's — bad in any system with an audit trail. Same class of setting as Jellyfin's "Known proxies" and NetBird's `trustedHTTPProxies`.
- **`pull_policy: missing`, not upstream's `always`.** Upstream defaults to a floating tag where re-pulling makes sense; this file pins an exact version, so `always` would mean nine pointless registry round-trips on every rerun.
- **The site-creation wait loop was simplified.** Upstream's `create-site` opens with a ~15-line `jq` polling loop re-reading `common_site_config.json`. It's redundant here — `depends_on: configurator: service_completed_successfully` already guarantees the configurator exited 0, and writing that file is all it does. Upstream's version also uses backslash continuations inside a YAML folded scalar, a construct subtle enough not to transcribe untested.
- **Only `frontend` joins `main-net`**; the other ten containers stay on the private `erpnext-net`. Upstream puts everything on one network with no external network at all.
- **No Traefik.** Upstream's production overrides bundle Traefik with its own Let's Encrypt, which would collide with NGINX Proxy Manager on ports 80/443.

---

## 📜 License

ERPNext and Frappe are licensed separately (GPL-3.0 — see the [official repository](https://github.com/frappe/erpnext)). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
