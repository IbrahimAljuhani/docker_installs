# 🔗 LinkStack

Deploys [LinkStack](https://linkstack.org/) (a self-hosted Linktree/many.link alternative — one page with all your links) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

Adapted from the official [`linkstack-docker`](https://github.com/LinkStackOrg/linkstack-docker) image and its documented `docker-compose.yml` example. See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from upstream.

LinkStack is the simplest service in this repo so far: **one container**, SQLite embedded (no separate database container at all).

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy LinkStack

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Web/linkstack/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Web/linkstack/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service: one LinkStack deployment per host, under `~/docker/linkstack/`. Unlike this repo's other services, there's no password or secret to generate — LinkStack has no database credentials (SQLite, embedded in its own Docker volume) and creates its own app secret internally during its first-run setup wizard.

You'll also be asked whether to cap memory on the `linkstack` container (default suggestion: `512m`). Say no and it runs uncapped.

> 💡 **To change the memory limit later**: edit `MEM_LIMIT=` in `~/docker/linkstack/.env`, then rerun `deploy.sh` — it regenerates `docker-compose.override.yml` from whatever `.env` currently has and reapplies it with `docker compose up -d`.

You'll also be asked whether to publish a host port for direct access without NPM (e.g. `http://<server-ip>:8095`) — useful for a quick first check before wiring up NPM. Default is no. This maps to the container's plain-HTTP port 80 (not 443) specifically so a quick test doesn't hit LinkStack's self-signed HTTPS certificate.

- **If you said no** to a host port, you're then prompted for the public domain you plan to point NPM at (e.g. `links.example.com`) — this sets `SERVER_NAME` (Apache's `ServerName` for both the HTTP and HTTPS vhosts).
- **If you said yes** to a host port, the domain question is skipped — `SERVER_NAME` is set to your server's bare IP automatically. Unlike Vikunja/Plane, LinkStack has no CORS or host-header check, so a mismatched `SERVER_NAME` won't break access — it's just used for Apache's own canonical-URL generation.

Either way, this choice (like memory) is only asked once — rerunning `deploy.sh` reuses `.env` and **never overwrites an existing `docker-compose.yml`** at `~/docker/linkstack/` (so any manual edits you make there survive reruns; delete it yourself first if you want the latest version from this repo).

---

## 👤 First Login

LinkStack has **no default admin account**. Visiting the site for the first time runs its own setup wizard, which will:

1. Check server dependencies
2. Set up the database (SQLite, automatic — no input needed)
3. Create your admin account
4. Configure the app

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

> ⚠️ **This service is different from every other one in this repo.** LinkStack's container serves HTTPS internally on port 443 with its own self-signed certificate, and upstream's own docs are explicit: *"Make sure to use HTTPS to access your container to avoid mixed content errors."* Proxying plain HTTP to port 80 (like every other service here) will cause broken/mixed-content pages.

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: the same domain you entered during `deploy.sh` (should match `SERVER_NAME` in `.env`)
   - **Forward Hostname/IP**: `linkstack-app`
   - **Forward Port**: `443`
   - **Forward Scheme**: **HTTPS** — not the default HTTP. NPM does not validate the container's self-signed certificate, so this works without extra configuration; you just need to actually pick HTTPS in the dropdown.
3. Enable **SSL** with Let's Encrypt from the UI (this is the outward-facing cert visitors see; it's separate from the container's internal self-signed one).

✅ No host port is published for `linkstack-app` by default — NPM reaches it by container name over `main-net`.

---

## 🛠️ Management Commands

```bash
cd ~/docker/linkstack
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f linkstack` | Follow the app's logs |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest image |

LinkStack also has its own **in-app one-click updater** — after logging in as admin, an update notification appears in the Admin Panel if a new version is available.

---

## 📌 Known Simplifications vs. Upstream

- Upstream's own example publishes a host port unconditionally (e.g. `8190:443`); here that's optional (default: no), matching this repo's "NPM-only unless you opt in" convention.
- No private `<service>-net` — every other service here isolates its database on a private network and only joins the app container to `main-net`. LinkStack has nothing to isolate (one container, no database container), so `linkstack-app` joins `main-net` directly.
- `PHP_MEMORY_LIMIT` (LinkStack's own PHP-level memory setting) and `UPLOAD_MAX_FILESIZE` are left at upstream's defaults (`256M` / `8M`) rather than exposed as prompts — this repo's own `MEM_LIMIT` prompt controls the container's overall memory instead, which is a different thing.

---

## 📜 License

LinkStack itself is licensed separately (GPL-3.0 — see the [official repository](https://github.com/LinkStackOrg/LinkStack) for terms). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
