# 🛡️ AdGuard Home

Deploys [AdGuard Home](https://adguard.com/en/adguard-home/overview.html) (network-wide ad/tracker blocking via DNS, plus a DNS filtering/analytics dashboard) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front its admin UI.

Uses the [official `adguard/adguardhome` image](https://hub.docker.com/r/adguard/adguardhome) (180M+ pulls). See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from a typical example.

Like this repo's Pi-hole, **DNS (port 53) can't go through NGINX Proxy Manager at all** — NPM only speaks HTTP/HTTPS. Unlike Pi-hole, AdGuard Home has **no unattended/env-var-based setup** — first visit always runs an interactive browser wizard where you pick the admin UI's port and create your own username/password.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy AdGuard Home

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/DNS/adguard/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/DNS/adguard/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service: one AdGuard Home deployment per host, under `~/docker/adguard/`. There's no password to generate — the admin account is created entirely through AdGuard Home's own first-run setup wizard, not environment variables.

### ⚠️ Before you deploy: port 53 is almost certainly already taken

On a fresh Ubuntu server, `systemd-resolved` binds port 53 by default — AdGuard Home cannot start until it's freed. `deploy.sh` checks this up front and tells you exactly what to fix, but you can also do it before running `deploy.sh`:

```bash
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo rm /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
```

You'll also be asked whether to cap memory on the `adguard-app` container (default suggestion: `256m`). Say no and it runs uncapped.

> 💡 **To change the memory limit or host ports later**: edit `~/docker/adguard/.env`, then rerun `deploy.sh` — it regenerates `docker-compose.override.yml` from whatever `.env` currently has and reapplies it with `docker compose up -d`.

You'll also be asked whether to publish host ports for direct access to both the setup wizard **and** the admin UI without NPM (default suggestions: `3000` for setup, `80` for the admin UI afterward). Default is no — see [First Run & Setup Wizard](#-first-run--setup-wizard) below for what that means for bootstrapping through NPM instead.

---

## 🧙 First Run & Setup Wizard

AdGuard Home has **no default admin account**. The setup wizard walks you through:

1. Choosing the **Admin Web Interface** port — **pick `80`**, to match every other service in this repo's "NPM forwards to container port 80" convention. (The wizard also asks about the DNS server port — leave that at `53`, already handled by `docker-compose.yml`.)
2. Creating your own admin username and password.
3. Optionally importing existing settings.

### If you published host ports (the simpler path)

Visit `http://<server-ip>:3000` to run the wizard, then `http://<server-ip>:<admin-port>` afterward.

### If you didn't (NPM-only)

NPM can proxy to a container by name even before that container has "finished setting up" — it's just forwarding traffic. Bootstrap it in two steps:
1. Create a Proxy Host pointing to `adguard-app`, port `3000`, run the wizard through that domain, and pick port `80` for the Admin Web Interface as instructed above.
2. Edit that same Proxy Host afterward, changing the forward port from `3000` to `80` — now it points at the real admin UI going forward.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager) — admin UI only

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: your chosen domain, e.g. `adguard.example.com`
   - **Forward Hostname/IP**: `adguard-app`
   - **Forward Port**: `3000` at first (for the setup wizard), then `80` afterward (see above)
3. Enable **SSL** with Let's Encrypt from the UI.

### Recommended: tell AdGuard Home to trust NPM

Without this, AdGuard Home's admin dashboard shows every visitor as NPM's own container IP instead of their real address (DNS query logging itself is unaffected — DNS traffic hits port 53 directly, never through NPM). Find `main-net`'s subnet:

```bash
docker network inspect main-net --format '{{ (index .IPAM.Config 0).Subnet }}'
```

Add it to `trusted_proxies` in `~/docker/adguard/AdGuardHome.yaml` (inside the `adguard-conf` volume — `docker exec -it adguard-app sh` to edit it, or use the Admin UI's own settings if exposed there), then restart: `cd ~/docker/adguard && docker compose restart`.

✅ No host port is published for `adguard-app`'s web UI by default — NPM reaches it by container name over `main-net`. This is unrelated to DNS itself, which is always reachable on port 53 regardless of NPM/SSL setup.

---

## 👉 Making AdGuard Home Actually Block Anything

Deploying the container does nothing on its own — AdGuard Home only blocks ads for devices that actually use it as their DNS server. After setup:

1. Log in to your **router's admin panel** and set its DNS server to this server's IP (usually under WAN, LAN, or DHCP settings) — this covers every device on your network automatically.
2. Alternatively, for a partial rollout, set individual devices' DNS manually instead of the whole router.

---

## 🛠️ Management Commands

```bash
cd ~/docker/adguard
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f adguardhome` | Follow the app's logs |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest image |

AdGuard Home also has its own **in-app update check** (Settings → General → Check for updates) — the update itself still has to be applied via the commands above.

---

## 📌 Known Simplifications vs. Common Examples

- DHCP server, DNS-over-TLS (853), DNS-over-QUIC (853/udp), and DNSCrypt (5443) are not set up here — this deploys AdGuard Home as a plain DNS-only ad blocker plus its web dashboard, the most common use case. Add the relevant ports/config in `~/docker/adguard/docker-compose.yml` yourself if you need them.
- `adguard-work`/`adguard-conf` are named Docker volumes rather than bind mounts — simpler permissions, no host-side directory to pre-create.

---

## 📜 License

AdGuard Home itself is licensed separately (GPL-3.0 — see the [official repository](https://github.com/AdguardTeam/AdGuardHome) for terms). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
