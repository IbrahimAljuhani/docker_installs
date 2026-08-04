# 🕳️ Pi-hole

Deploys [Pi-hole](https://pi-hole.net/) (network-wide ad/tracker blocking via DNS) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front its web UI.

Adapted from the [official `docker-pi-hole` compose example](https://github.com/pi-hole/docker-pi-hole) (v6, `FTLCONF_*` environment variables). See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from upstream.

Pi-hole is different from every other service in this repo in one fundamental way: **DNS (port 53) can't go through NGINX Proxy Manager at all** — NPM only speaks HTTP/HTTPS, and DNS is a completely different protocol. Only Pi-hole's web UI (port 80) follows this repo's usual NPM/optional-host-port pattern; DNS itself is always directly reachable.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy Pi-hole

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/DNS/pi-hole/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/DNS/pi-hole/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service: one Pi-hole deployment per host, under `~/docker/pi-hole/`.

### ⚠️ Before you deploy: port 53 is almost certainly already taken

On a fresh Ubuntu server, `systemd-resolved` binds port 53 by default — Pi-hole cannot start until it's freed. `deploy.sh` checks this up front and tells you exactly what to fix (rather than letting the container fail with a generic "port is already allocated" error), but you can also do it before running `deploy.sh`:

```bash
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo rm /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
```

`deploy.sh` generates and saves a random web-UI password (to `.env`, `600`, and a one-time readable copy at `~/docker/pi-hole/.pihole-docker-secrets.txt`, `600`).

You'll also be asked whether to cap memory on the `pihole-app` container (default suggestion: `512m`). Say no and it runs uncapped.

> 💡 **To change the memory limit later**: edit `MEM_LIMIT=` in `~/docker/pi-hole/.env`, then rerun `deploy.sh` — it regenerates `docker-compose.override.yml` from whatever `.env` currently has and reapplies it with `docker compose up -d`.

You'll also be asked whether to publish a host port for **direct web-UI access** without NPM (default suggestion: `8081` — deliberately *not* `80`, since NGINX Proxy Manager already owns host port 80 on this server). Default is no.

> 📌 This host-port question is only about the **web UI**. DNS itself (port 53) is never optional — see [docker-compose.yml](docker-compose.yml)'s header comment for why.

Either way, this choice (like memory and the password) is only asked once — rerunning `deploy.sh` reuses `.env` and **never overwrites an existing `docker-compose.yml`** at `~/docker/pi-hole/` (so any manual edits you make there survive reruns; delete it yourself first if you want the latest version from this repo).

---

## 👉 Making Pi-hole Actually Block Anything

Deploying the container does nothing on its own — Pi-hole only blocks ads for devices that actually use it as their DNS server. After deploying:

1. Log in to your **router's admin panel** and set its DNS server to this server's IP (usually under WAN, LAN, or DHCP settings) — this covers every device on your network automatically.
2. Alternatively, for a partial rollout, set individual devices' DNS manually instead of the whole router.

Log in to the web UI with the password from the secrets file above — there's no username, just the one password.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager) — web UI only

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: your chosen domain, e.g. `pihole.example.com`
   - **Forward Hostname/IP**: `pihole-app`
   - **Forward Port**: `80`
3. Enable **SSL** with Let's Encrypt from the UI.

✅ No host port is published for the web UI by default — NPM reaches it by container name over `main-net`. This is unrelated to DNS itself, which is always reachable on port 53 regardless of NPM/SSL setup.

---

## 🛠️ Management Commands

```bash
cd ~/docker/pi-hole
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f pihole` | Follow the app's logs |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest image |
| `docker exec -it pihole-app pihole -up` | Update ad/tracker block lists (gravity) on demand |

---

## 📌 Known Simplifications vs. Upstream

- Upstream's own example also publishes port 443 (Pi-hole's own self-signed HTTPS); dropped here — NPM handles real TLS termination for the web UI instead, same reasoning as every other service in this repo.
- `NET_ADMIN` capability is dropped — upstream's own docs say it's only needed for Pi-hole's built-in DHCP server, which this deploy doesn't set up (most home networks already get DHCP from their router). `SYS_TIME`/`SYS_NICE` are kept, matching upstream's defaults.
- No DHCP or NTP server setup — Pi-hole can do both, but neither is configured here; this deploys Pi-hole as a DNS-only ad blocker, the most common use case.

---

## 📜 License

Pi-hole itself is licensed separately (EUPL-1.2 — see the [official repository](https://github.com/pi-hole/pi-hole) for terms). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
