# 🖼️ PhotoPrism

Deploys [PhotoPrism](https://www.photoprism.app/) (AI-powered photo management — face recognition, object classification, places, and search) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

Adapted from upstream's own [`compose.yaml`](https://dl.photoprism.app/docker/compose.yaml) and its [nginx reverse-proxy guide](https://docs.photoprism.app/getting-started/proxies/nginx/). See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations.

Two containers: `photoprism-app` and a MariaDB database.

---

## ⚠️ PhotoPrism Writes To Your Photo Folder

Unlike this repo's [Jellyfin](../../Media/jellyfin/) and [Plex](../../Media/plex/) — which mount your media **read-only** — PhotoPrism mounts your photo folder **read-write**, because organizing files and writing YAML sidecar metadata alongside them is core to how it works.

That's normal and expected for this app, but it means **PhotoPrism can modify and move your original files**. Before pointing it at an irreplaceable library:

- Make sure you have a backup of those originals that PhotoPrism can't reach.
- Or set `PHOTOPRISM_READONLY: "true"` in `~/docker/photoprism/docker-compose.yml` to forbid it from touching originals — at the cost of reduced functionality (no import/organize/move features).

Also see [Backups](#-backups) below: this repo's Backup option covers PhotoPrism's *index*, not your photo files.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy PhotoPrism

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Photos/photoprism/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Photos/photoprism/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service: one PhotoPrism deployment per host, under `~/docker/photoprism/`.

`deploy.sh` generates the admin password and both MariaDB passwords, saving them to `.env` (`600`) and a one-time readable copy at `~/docker/photoprism/.photoprism-docker-secrets.txt` (`600`). Web login is username **`admin`** plus that generated password.

### ⚠️ About the memory-limit prompt

Every other service in this repo offers an optional memory cap and it's harmless. **PhotoPrism is the exception** — upstream explicitly warns that capping memory can cause restart loops, because the indexer temporarily needs a lot of RAM to process large files. `deploy.sh` prints that warning before asking, and the default (**no limit**) is the recommended answer here.

Upstream also recommends at least **4 GB of swap** on the host for the same reason.

You'll also be asked whether to publish a host port for direct access without NPM (default suggestion: `2342`). Default is no.

- **If you said no**, you're prompted for the public domain you'll point NPM at — this becomes `PHOTOPRISM_SITE_URL=https://your-domain/`.
- **If you said yes**, the domain question is skipped and `PHOTOPRISM_SITE_URL` is set to `http://<server-ip>:<port>/` automatically. PhotoPrism builds its links and redirects from this value, so scheme, host, **and the trailing slash** all matter.

> 💡 **To change the memory limit, host port, or site URL later**: edit `~/docker/photoprism/.env`, then rerun `deploy.sh` — it regenerates `docker-compose.override.yml` from whatever `.env` currently has and reapplies it with `docker compose up -d`.

---

## 👉 First Run: Nothing Appears Until You Index

PhotoPrism doesn't watch your folder automatically on first setup. After logging in, go to **Library → Index** and run the first scan — that's what actually reads your photo folder, builds thumbnails, and runs face/object recognition.

The first index can take a long while on a large library, and the very first container start also downloads TensorFlow models.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: your chosen domain, e.g. `photos.example.com` (must match `PHOTOPRISM_SITE_URL` in `.env`)
   - **Forward Hostname/IP**: `photoprism-app`
   - **Forward Port**: `2342`
   - Enable **Websockets Support**
3. Enable **SSL** with Let's Encrypt from the UI.

PhotoPrism's own internal TLS is **disabled on purpose** in this deployment (`PHOTOPRISM_DISABLE_TLS: "true"`), so NPM manages certificates — that's upstream's own documented recommendation for reverse-proxy setups. This is why the forward scheme stays plain **HTTP**, unlike this repo's [LinkStack](../../Web/linkstack/), which needs HTTPS forwarding.

> 📌 If PhotoPrism logs complaints about forwarded headers, set `PHOTOPRISM_TRUSTED_PROXY` to `main-net`'s subnet. Usually unnecessary — `main-net` is a normal Docker bridge network, already inside the range PhotoPrism trusts by default. Find the subnet with:
> ```bash
> docker network inspect main-net --format '{{ (index .IPAM.Config 0).Subnet }}'
> ```

✅ No host port is published for `photoprism-app` by default — NPM reaches it by container name over `main-net`. `mariadb` stays on the private `photoprism-net` only.

---

## 💾 Backups

This repo's **Backup** option (in `services.sh`) captures PhotoPrism's **index** — a proper `mariadb-dump` of the database (albums, faces, labels, ratings, metadata) plus the storage volume (cache, thumbnails, sidecars).

**It does not back up your photos.** Your originals live in the folder you chose at deploy time, outside `~/docker/photoprism/`. That folder is the irreplaceable half — back it up separately, with whatever you already use for important files.

---

## 🛠️ Management Commands

```bash
cd ~/docker/photoprism
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f photoprism` | Follow the app's logs |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest images |
| `docker compose exec photoprism photoprism index` | Run an index scan from the CLI |

> 🩺 **Stuck in a restart loop?** Upstream's most common causes are memory pressure (see the memory-limit note above), a filesystem that doesn't support file locking, or a database issue. `docker compose logs -f photoprism` will usually say which.

---

## 📌 Known Simplifications vs. Upstream

- **Internal TLS disabled** (`PHOTOPRISM_DISABLE_TLS: "true"`). Upstream's example defaults to serving HTTPS with a self-signed certificate; its own nginx guide says to disable that behind a reverse proxy, which is what this does.
- **`PHOTOPRISM_INIT` is `"tensorflow"`**, dropping upstream's `"https"` — that option installs certificate tooling this deployment no longer needs with TLS off, and skipping it speeds up first start.
- **Upstream's optional Ollama, Open WebUI, and Watchtower services are dropped.** They're gated behind Compose profiles (so they never start by default anyway), and this repo tracks Ollama and Open WebUI as their own services under the **AI** category rather than nesting them inside another service's stack.
- **`restart: unless-stopped` is enabled** on both containers. Upstream ships it commented out on the app with a caution that restart loops can mask config problems — this repo enables it like every other service and documents the troubleshooting note above instead.
- Upstream's own example publishes `2342:2342` unconditionally; here that's optional (default: no), matching this repo's "NPM-only unless you opt in" convention.
- `storage` and the database use Docker volumes rather than upstream's `./storage` and `./database` bind mounts — nothing on the host needs to read them directly.

---

## 📜 License

PhotoPrism itself is licensed separately (AGPL-3.0, with some features under a separate commercial license — see the [official repository](https://github.com/photoprism/photoprism) for terms). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
