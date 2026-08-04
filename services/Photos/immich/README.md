# 📷 Immich

Deploys [Immich](https://immich.app/) (a self-hosted Google Photos alternative — photo/video backup with face recognition and smart search) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

Adapted from the official release-attached [`docker-compose.yml`](https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml) — the actual self-host distribution artifact (the root of Immich's GitHub repo builds from source and is for local development, not this). See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from upstream.

Immich is a 4-container stack: `immich-server` (app/API), `immich-machine-learning` (face recognition / smart search), `redis`, and a Postgres image with the pgvector/vectorchord extension built in — **must** be this specific image (`ghcr.io/immich-app/postgres`), a plain `postgres` image won't work since Immich's smart search relies on the vector extension.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy Immich

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Photos/immich/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Photos/immich/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service: one Immich deployment per host, under `~/docker/immich/`.

> ⚠️ **Resources**: the machine-learning container runs CPU-only by default (see [Known Simplifications](#-known-simplifications-vs-upstream)) and can be memory-hungry the first time it indexes a large library. 2 GB+ free RAM beyond whatever you cap `immich-app` at is a reasonable minimum.

`deploy.sh` generates and saves a random `DB_PASSWORD` (to `.env`, `600`, and a one-time readable copy at `~/docker/immich/.immich-docker-secrets.txt`, `600`).

You'll also be asked whether to cap memory on the `immich-app` container (default suggestion: `2g`) — `immich-machine-learning`/`redis`/`database` stay unbounded, same "main container only" convention every other service here follows.

> 💡 **To change the memory limit later**: edit `MEM_LIMIT=` in `~/docker/immich/.env`, then rerun `deploy.sh` — it regenerates `docker-compose.override.yml` from whatever `.env` currently has and reapplies it with `docker compose up -d`.

You'll also be asked whether to publish a host port for direct access without NPM (e.g. `http://<server-ip>:2283`) — useful for a quick first check before wiring up NPM. Default is no.

Unlike Vikunja/Plane/OpenProject, **Immich has no CORS or host-header check** — there's no domain question during setup at all, and no env var to keep in sync with how you access it.

Either way, this choice (like memory and the DB password) is only asked once — rerunning `deploy.sh` reuses `.env` and **never overwrites an existing `docker-compose.yml`** at `~/docker/immich/` (so any manual edits you make there survive reruns; delete it yourself first if you want the latest version from this repo).

---

## 👤 First Login

Immich has **no default admin account**. Visiting the site for the first time runs its own setup wizard where you create your own account — the first person to register becomes the admin.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: your chosen domain, e.g. `photos.example.com`
   - **Forward Hostname/IP**: `immich-app`
   - **Forward Port**: `2283`
   - Enable **Websockets Support**
3. Enable **SSL** with Let's Encrypt from the UI.
4. On the **Advanced** tab (the ⚙️ icon), add — Immich's own docs recommend this for large photo/video uploads, verified against [Immich's reverse-proxy docs](https://docs.immich.app/administration/reverse-proxy):
   ```
   client_max_body_size 50000M;
   proxy_request_buffering off;
   proxy_read_timeout 600s;
   proxy_send_timeout 600s;
   send_timeout 600s;
   ```

✅ No host port is published for `immich-app` by default — NPM reaches it by container name over `main-net`. `immich-machine-learning`, `redis`, and `database` stay on the private `immich-net` only.

> 📌 Immich must be served at the root of a (sub)domain — its own docs say it does **not** support being served on a sub-path like `example.com/immich`.

---

## 🛠️ Management Commands

```bash
cd ~/docker/immich
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check status of all 4 containers |
| `docker compose logs -f immich-server` | Follow the app's logs |
| `docker compose logs -f immich-machine-learning` | Follow ML/face-recognition logs |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest images |

Immich also shows an **in-app update notification** for admins when a new version is available, with a link to the changelog — updating itself is still done via the commands above (Immich has no one-click in-app updater, unlike LinkStack).

---

## 📌 Known Simplifications vs. Upstream

- **No hardware acceleration** for either video transcoding (`immich-server`) or ML inference (`immich-machine-learning`) — both run CPU-only. Upstream's own compose file has these commented out too by default; if you have a compatible GPU, see [Immich's hardware acceleration docs](https://docs.immich.app/features/ml-hardware-acceleration) and hand-edit `~/docker/immich/docker-compose.yml` to add the relevant `extends:` block.
- Upstream's own example publishes a host port unconditionally (`2283:2283`); here that's optional (default: no), matching this repo's "NPM-only unless you opt in" convention.
- Image references aren't pinned to a specific `sha256` digest here (upstream pins them for maximum reproducibility) — matches this repo's convention of plain version tags everywhere else (e.g. `postgres:17`), traded for simpler upgrades (`docker compose pull`) over digest-level reproducibility.
- `redis`/`database`/`immich-machine-learning` stay off `main-net` entirely; only `immich-server` joins it — upstream's own compose doesn't define any custom networks at all (everything shares Compose's single default network, with nothing external to join).

---

## 📜 License

Immich itself is licensed separately (AGPL-3.0 — see the [official repository](https://github.com/immich-app/immich) for terms). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
