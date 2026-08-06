# 🎬 Plex

Deploys [Plex Media Server](https://www.plex.tv/) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

Uses the [official `plexinc/pms-docker` image](https://hub.docker.com/r/plexinc/pms-docker) from Plex Inc. (900M+ pulls). See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from upstream's own examples.

---

## ⚠️ Read This First: Plex Is Not Open Source

Every other service in this repo is open-source software you fully control. Plex is different, and it's worth knowing before you deploy:

- **Proprietary freemium software** — the server binary is closed source.
- **Requires a free Plex account.** The server links to plex.tv, and that's the normal path for clients to find it. There's no fully offline/account-free mode.
- **Some features are paid** (Plex Pass), notably **hardware transcoding** — so the `/dev/dri` passthrough option this script offers does nothing on a free account.

If you want a fully open-source, no-account media server instead, this repo also ships **[Jellyfin](../jellyfin/)**, which covers the same ground. Nothing stops you running both.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy Plex

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Media/plex/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Media/plex/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service: one Plex deployment per host, under `~/docker/plex/`.

### You'll be guided through:

| # | Prompt | Notes |
|---|---|---|
| 1 | **Media library path** | Required — Plex has nothing to serve without it. Mounted read-only at `/data` inside the container. |
| 2 | **Memory limit for the `plex` container?** (default: **no** → unbounded) | Suggested default `2g` if you say yes |
| 3 | **Publish a host port for direct access?** (default: **no**) | Suggested default `32400` |
| 4 | **Hardware transcoding passthrough?** (only asked if `/dev/dri` exists) | ⚠️ Needs a paid **Plex Pass** to actually be used |
| 5 | **Claim token** (asked last, on purpose) | See below |

### About the claim token

The claim token is what links this server to your Plex account. You get it from **[plex.tv/claim](https://www.plex.tv/claim)** while signed in — and **it expires about 4 minutes after you generate it**.

That's exactly why `deploy.sh` asks for it *last*, after every other question is out of the way: the clock only starts once you actually go fetch it.

**It's optional.** Leave it blank and the server deploys unclaimed — you can then claim it by opening Plex from a browser **on the same local network** as the server (Plex only permits unclaimed setup from the local network, as a security measure). Or put a fresh token into `PLEX_CLAIM` in `~/docker/plex/.env` later and rerun `deploy.sh` within the 4-minute window.

> 💡 **To change the memory limit, host port, or media path later**: edit `~/docker/plex/.env`, then rerun `deploy.sh` — it regenerates `docker-compose.override.yml` from whatever `.env` currently has and reapplies it with `docker compose up -d`.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: your chosen domain, e.g. `plex.example.com`
   - **Forward Hostname/IP**: `plex-app`
   - **Forward Port**: `32400`
   - Enable **Websockets Support**
3. Enable **SSL** with Let's Encrypt from the UI.

### Required: Plex's own settings

Unlike most services here, Plex needs matching configuration on **its** side too. In **Settings → Network**:

- **Custom server access URLs**: `https://plex.example.com:443` — without this, Plex keeps advertising its internal address and clients bypass your proxy.
- **Secure connections**: set to **`Preferred`**, not `Required`. Some clients (Roku, PlayStation, older smart TVs) can't do HTTPS at all and will stop working entirely on `Required`.
- **Remote Access**: turn it **off** when NPM is fronting Plex. Otherwise Plex also tries to punch its own port-forward through your router, which defeats the point of the proxy and can cause conflicting connection paths.

> 📌 **Plex clients don't only use your proxy.** Plex apps discover servers through your plex.tv account and connect directly on port 32400 when they can. The reverse proxy mainly matters for the web UI and for clients coming from outside your network.

✅ No host port is published for `plex-app` by default — NPM reaches it by container name over `main-net`.

---

## 🛠️ Management Commands

```bash
cd ~/docker/plex
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f plex` | Follow the app's logs |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest image |

---

## 📌 Known Simplifications vs. Upstream

- **Bridge networking, not host.** Upstream prefers host networking (calling bridge "more complicated") because it enables LAN autodiscovery/DLNA. This repo uses bridge on `main-net` so NPM can reach it by container name like every other service — the tradeoff is that **LAN autodiscovery and DLNA won't work**; clients find the server through your plex.tv account instead, which is the normal path anyway. (This repo's Home Assistant made the opposite call — see [its README](../../Home-Automation/home-assistant/) for why that one genuinely needed host networking.)
- **Only port 32400 is wired up.** The secondary discovery ports (1900/udp, 3005, 8324, 32410–32414/udp, 32469) are omitted, since they exist for the LAN autodiscovery that bridge networking already precludes.
- Upstream's own examples publish host ports unconditionally; here that's optional (default: no), matching this repo's "NPM-only unless you opt in" convention.
- `/transcode` is a Docker volume rather than a host path — transcoding scratch space can hit tens of GB, so Docker manages it instead of silently filling a directory you picked.
- Media is mounted **read-only** (`:ro`) — Plex only reads/streams your library and keeps its metadata in `/config`.

---

## 📜 License

Plex Media Server is **proprietary software** — see [Plex's own terms](https://www.plex.tv/about/privacy-legal/) for what you're agreeing to. This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
