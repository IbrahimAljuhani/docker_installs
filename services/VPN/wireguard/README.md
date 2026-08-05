# 🔐 WireGuard

Deploys WireGuard via [wg-easy](https://github.com/wg-easy/wg-easy) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front its web UI.

Plain WireGuard has **no web UI at all** — it's config-file/CLI only. wg-easy is the community-standard wrapper that adds one (add/remove peers, QR codes for mobile setup), which is why this repo builds "WireGuard" as wg-easy specifically rather than a bare WireGuard image — see [docker-compose.yml](docker-compose.yml)'s header comment for the exact, deliberate deviations from wg-easy's own official compose example.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy WireGuard

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/VPN/wireguard/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/VPN/wireguard/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service: one wg-easy deployment per host, under `~/docker/wireguard/`.

### You'll be guided through:

| # | Prompt | Notes |
|---|---|---|
| 1 | **Public IP or domain** (always asked) | The actual VPN endpoint your devices dial over UDP — e.g. `vpn.example.com` or your server's public IP. Unlike every other service's domain question, this is **never optional or NPM-related** — WireGuard traffic is raw UDP and can never go through NPM. |
| 2 | **Memory limit for the `wg-easy-app` container?** (default: **no** → unbounded) | Suggested default `256m` if you say yes |
| 3 | **Publish a host port for direct web-UI access without NPM?** (default: **no**) | Suggested default `51821`. Saying yes also sets `INSECURE=true` automatically — see [below](#️-you-cant-log-in-with-an-insecure-connection-use-https) for why direct access needs this. |

`deploy.sh` generates a random admin password and sets it via wg-easy's own `INIT_*` "Unattended Setup" environment variables (see [wg-easy's own docs](https://wg-easy.github.io/wg-easy/latest/advanced/config/unattended-setup/)) — this skips wg-easy's interactive first-visit browser wizard entirely, matching every other service in this repo's "credentials generated automatically" convention. The generated password is saved to `.env`, `600`, and a one-time readable copy at `~/docker/wireguard/.wireguard-docker-secrets.txt`, `600`.

> 💡 **To change the memory limit or web-UI host port later**: edit `~/docker/wireguard/.env`, then rerun `deploy.sh` — it regenerates `docker-compose.override.yml` from whatever `.env` currently has and reapplies it with `docker compose up -d`.

Either way, this choice (like the password) is only asked once — rerunning `deploy.sh` reuses `.env` and **never overwrites an existing `docker-compose.yml`** at `~/docker/wireguard/` (so any manual edits you make there survive reruns; delete it yourself first if you want the latest version from this repo).

---

## 👤 First Login & Adding a Device

Log in to the web UI with username `admin` and the password from the secrets file above. Once in, click **Add** to create a peer for each device — wg-easy shows a QR code (scan directly in the WireGuard mobile app) and a downloadable `.conf` file (for desktop clients).

---

## 🌐 Reverse Proxy (NGINX Proxy Manager) — web UI only

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: your chosen domain, e.g. `wg.example.com` (can be different from `INIT_HOST` — this one's just for the web UI, `INIT_HOST` is the VPN endpoint peers dial directly)
   - **Forward Hostname/IP**: `wg-easy-app`
   - **Forward Port**: `51821`
3. Enable **SSL** with Let's Encrypt from the UI.

✅ No host port is published for the web UI by default — NPM reaches it by container name over `main-net`. This is unrelated to the VPN data port (51820/udp), which is always directly reachable regardless of NPM/SSL setup, same as Pi-hole's DNS port.

### ⚠️ "You can't log in with an insecure connection. Use HTTPS."

wg-easy **refuses login entirely** unless it can confirm the connection was HTTPS — it checks the `X-Forwarded-Proto` header, which is absent on a direct, un-proxied connection. This isn't just a warning; it's a hard block, and it applies in two different situations:

- **Direct host-port access** (no NPM): always blocked otherwise — this is why `deploy.sh` automatically sets `INSECURE=true` in `.env` only when you opt into the direct host-port during setup (see [docker-compose.yml](docker-compose.yml)'s header comment). If you enabled the host port after the fact by hand-editing `.env`, add `INSECURE=true` yourself and `docker compose up -d`.
- **Through NPM**: NPM sends `X-Forwarded-Proto: https` correctly by default once SSL is enabled on the Proxy Host, so this should just work without `INSECURE=true`. If you still hit the error through a correctly-configured NPM+SSL setup, double check the Proxy Host's SSL is actually enabled and Let's Encrypt issued successfully — an unencrypted Proxy Host (SSL off) will trigger this exact error too, since NPM itself isn't sending HTTPS in that case.

---

## 🛠️ Management Commands

```bash
cd ~/docker/wireguard
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f wg-easy` | Follow the app's logs |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest image |

---

## 📌 Known Simplifications vs. Upstream

- Upstream's own example publishes the web UI port (51821) unconditionally; here that's optional (default: no), matching this repo's "NPM-only unless you opt in" convention.
- IPv6 is disabled entirely (`DISABLE_IPV6=true`, and `wg-net` is IPv4-only) — upstream's own example enables it by default. This also sidesteps wg-easy's `INIT_IPV6_CIDR` variable, which its own docs say must be set together with `INIT_IPV4_CIDR` as a group; skipping both lets wg-easy use its own sensible built-in VPN subnet default instead of this repo guessing one. Change this later via the web UI's settings page if you need IPv6.
- `INIT_DNS`/`INIT_ALLOWED_IPS` are left unset for the same reason (avoiding wg-easy's grouped-variable requirements) — new peers get wg-easy's own built-in defaults, changeable per-peer in the web UI.
- `wg-net`'s subnet (`10.42.42.0/24`) is upstream's own documented default, kept as-is — if it happens to collide with your actual LAN's address range (rare, but possible on some home networks), hand-edit the `subnet:` value in `~/docker/wireguard/docker-compose.yml` before first deploy.

---

## 📜 License

wg-easy itself is licensed separately (Apache 2.0 — see the [official repository](https://github.com/wg-easy/wg-easy) for terms). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
