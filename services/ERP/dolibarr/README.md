# 📗 Dolibarr

Deploys [Dolibarr ERP & CRM](https://www.dolibarr.org/) (invoicing, orders, stock, contacts, projects, accounting — modular, enable only what you use) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

Uses the [official `dolibarr/dolibarr` image](https://hub.docker.com/r/dolibarr/dolibarr) maintained by the Dolibarr team. See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from their own compose example.

Three containers: `dolibarr-app` (Apache + PHP + Dolibarr), `dolibarr-cron` (the same image running only the scheduled-job loop) and `dolibarr-db` (MariaDB).

> 📌 **Why a separate container just for cron?** Because the image can be a web server *or* a cron runner, never both — `DOLI_CRON=1` makes its entrypoint run the scheduled-job loop **instead of** Apache. Upstream documents this two-container shape in their own [`examples/with-cron/`](https://github.com/Dolibarr/dolibarr-docker/tree/main/examples/with-cron). Set the flag on the web container by mistake and the port stays published while nothing listens on it: every request dies with *connection reset by peer*, and the only hint in the logs is `cron_run_jobs.php` printing its usage message.

---

## 📗 Which ERP should I pick?

This repo now has three, and they're aimed at genuinely different things:

| | Containers | Realistic RAM | Best for |
|---|---|---|---|
| **Dolibarr** | 3 | 1 GB | Small businesses. Easiest to run and to learn; modular, so you enable only invoicing or only stock if that's all you need. |
| [**Odoo**](../odoo/) | 2 (+ per instance) | 2 GB | Multi-company or multi-instance setups; huge app ecosystem. This repo supports **several named instances** on one host. |
| [**ERPNext**](../erpnext/) | 11 | 4 GB min, 8 GB comfortable | Manufacturing, deeper accounting, heavy customisation via the Frappe framework. |

Dolibarr is the lightest by a wide margin — it's the one to try first if you're unsure.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows.

### 2. Deploy Dolibarr

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/ERP/dolibarr/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/ERP/dolibarr/docker-compose.yml
curl -fsSL -o backup.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/ERP/dolibarr/backup.sh
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service (unlike [Odoo](../odoo/), which supports multiple named instances) — one Dolibarr deployment per host, under `~/docker/dolibarr/`.

You'll be asked for:

| Question | Notes |
|---|---|
| Memory limit | Optional, suggested `1g`, applied to `dolibarr-app` only. |
| Host port | Optional, default `8086` → the container's `80`. |
| **Domain** | Asked only if you said **no** to a host port — it becomes `DOLI_URL_ROOT`. |

There's **no web installer to click through**: the image installs Dolibarr on first boot (`DOLI_INSTALL_AUTO=1`) using credentials `deploy.sh` generates. They're saved to `.env` (`600`) and a readable copy at `~/docker/dolibarr/.dolibarr-docker-secrets.txt` (`600`).

Rerunning `deploy.sh` is safe — it reuses `.env` and won't reinstall over an existing database.

---

## 👤 First Login

Username **`admin`**, password from the secrets file:

```bash
cat ~/docker/dolibarr/.dolibarr-docker-secrets.txt
```

Dolibarr starts with almost every module **disabled** — that's by design, not a broken install. Go to **Home → Setup → Modules/Applications** and switch on what you need (Invoices, Products, Third parties, …). Set your company details under **Home → Setup → Company/Organization**.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: the domain you gave `deploy.sh`
   - **Forward Hostname/IP**: `dolibarr-app`
   - **Forward Port**: `80`
3. In NPM's **Custom Nginx Configuration** box (the **⚙️ gear icon** in the *Edit Proxy Host* dialog — not "Custom Locations"), paste the upload-size block.

   `deploy.sh` already wrote it to a file for you, so you don't have to copy it out of this page:

   ```bash
   cat ~/docker/dolibarr/npm-custom-nginx.conf
   ```

   <details>
   <summary>The block itself, if you'd rather copy it from here</summary>

   ```nginx
   client_max_body_size 40M;
   ```

   </details>

   Without it, attaching anything over NPM's default limit fails with **413 Request Entity Too Large** — and nothing appears in Dolibarr's own logs to explain it, because the request never reaches PHP.
4. Enable **SSL** with Let's Encrypt from the UI.

Scheme stays `http` — the container serves plain HTTP and NPM terminates TLS.

✅ No host port is published by default — NPM reaches `dolibarr-app` by container name over `main-net`. The database stays on the private `dolibarr-net`.

> ⚠️ **`DOLI_URL_ROOT` must match how you actually reach Dolibarr.** It's what Dolibarr builds links from — emailed invoice links, password resets, PDF asset paths. If you deployed with a host port and later move to NPM+SSL, edit `DOLI_URL_ROOT` in `~/docker/dolibarr/.env` to your `https://` domain and rerun `deploy.sh`. Same class of setting as [OpenProject](../../Projects/openproject/)'s `OPENPROJECT_HOST__NAME`.

---

## 🛠️ Management Commands

```bash
cd ~/docker/dolibarr
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check all three containers |
| `docker compose logs -f dolibarr-app` | Follow the app's logs |
| `docker compose logs -f dolibarr-cron` | Scheduled-job runs and their failures |
| `docker compose logs -f dolibarr-db` | Database logs |
| `docker compose pull && docker compose up -d` | Update to the latest patch of the pinned major |

> 💡 **Upgrading across major versions** (e.g. 23 → 24): bump `DOLIBARR_VERSION` in `.env`, then `docker compose up -d`. Dolibarr runs its own database migration on first start of the new version and shows the upgrade screen if anything needs confirming. **Back up first** — major upgrades change the schema.

---

## 💾 Backups

This service ships a DB-aware [`backup.sh`](backup.sh), so the **Backup** option in `services.sh` uses `mariadb-dump` instead of raw-copying live database files. The `documents` volume (every uploaded attachment and generated PDF) and `.env` are captured in the same run.

> 🔐 **`DOLI_INSTANCE_UNIQUE_ID` is an encryption salt, and losing it loses data.** Dolibarr encrypts stored passwords and API keys with it. A database restored **without** the matching value in `.env` leaves those fields permanently unreadable. `deploy.sh` generates it once and writes it to both `.env` and the secrets file — keep the secrets file with your backups.

---

## 📌 Notes & Deviations

- **Named volumes, not upstream's host paths.** Their example hardcodes `/home/dolibarr_mariadb`, `/home/dolibarr_documents` and `/home/dolibarr_custom`, which assume a layout outside the user's home and don't fit this repo's "everything under `~/docker/<service>`" convention.
- **MariaDB pinned to `11.8`, not `mariadb:latest`.** A floating database tag means an unrelated `docker compose pull` can jump a major version underneath a live database. Same version this repo's [ERPNext](../erpnext/) uses.
- **All passwords generated.** Upstream's example ships `dolidbpass`, `admin` and `mycronsecurekey` as literal defaults.
- **Upload limit raised to 32 MB** (PHP) with a matching **40 MB** on the NPM side. PHP's default here is **2 MB** — smaller than many single scanned invoices, and an ERP that silently refuses attachments is worse than one that's slightly generous. The two limits have to be raised together or the proxy rejects the upload before PHP sees it.
- **Scheduled jobs enabled**, via the dedicated `dolibarr-cron` container, where upstream's main example leaves cron off entirely. Dolibarr's scheduled jobs drive recurring invoices, stock alerts and email reminders; off by default means those silently never run, which in an ERP looks like data loss rather than a missing option. `DOLI_CRON_USER` is set alongside `DOLI_CRON_KEY` — the job needs **both**, and with only the key it loops printing its usage message.
- **`links:` dropped** — legacy Compose v1 syntax; the private `dolibarr-net` does the same job.
- **No host port by default**, where upstream publishes `80` unconditionally.
- **PostgreSQL is possible but not offered.** The image supports `DOLI_DB_TYPE=pgsql`, but upstream notes it then requires the manual web-based installer — which would defeat the unattended install this service is built around.

---

## 📜 License

Dolibarr is licensed separately (GPL-3.0-or-later — see the [official repository](https://github.com/Dolibarr/dolibarr)). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
