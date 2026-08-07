# 🔐 OpenVPN

Deploys [OpenVPN Access Server](https://openvpn.net/access-server/) — OpenVPN Inc.'s own distribution, with a web admin panel and built-in user management — behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front its web UI.

One container: `openvpn-as`, serving the admin UI, the client portal, and the VPN itself.

---

## ⚠️ Read This Before Deploying

Two things about this service differ from everything else in this repo. Neither is a bug, and both are easier to accept now than to discover after wiring up DNS.

**1. Two concurrent connections without a license.**
That's two simultaneous *tunnels*, not two accounts — you can create as many users as you like, but the third device connecting *at the same time* is refused with "maximum number of allowed clients reached". Disconnect one and the slot frees up.

It is **not** a time-limited trial: two connections stay free forever. This is the price of using the only OpenVPN image that is both official and actively maintained (see [Notes & Deviations](#-notes--deviations)).

> 💡 **Need more than two at once?** This repo's [WireGuard](../wireguard/) and [NetBird](../netbird/) services are unlimited and free. OpenVPN's reason to exist here is compatibility — existing `.ovpn` profiles, corporate clients, and hardware that speaks OpenVPN and nothing else. If you just want a VPN for your own devices, WireGuard is the better pick.

**2. UDP port 1194 must be reachable from the internet.**
That's the VPN tunnel itself. It's raw UDP: **no HTTP reverse proxy can carry it, and neither can Cloudflare Tunnel.** If your server is behind a home router you need a port-forward for `1194/udp` — exactly like [WireGuard](../wireguard/) needs one for `51820/udp` and [NetBird](../netbird/) for `3478/udp`.

NPM fronts the *web UI* only. The tunnel bypasses it entirely.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows.

### 2. Deploy OpenVPN

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/VPN/openvpn/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/VPN/openvpn/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service, under `~/docker/openvpn/`.

You'll be asked for:

| Question | Notes |
|---|---|
| **Public IP or domain** | Required — the address clients dial. Written into every client profile. |
| Memory limit | Optional, default suggestion `1g`. |
| Host port for the web UI | Optional, default `9443` → container's `943`. |
| TCP fallback | Optional, default `8443`. For clients on networks that block UDP. |

`deploy.sh` generates a random admin password and saves it to `.env` (`600`) and a readable copy at `~/docker/openvpn/.openvpn-docker-secrets.txt` (`600`).

> 💡 **Why `9443` and not `943`?** Only the *host* side moves — the container still serves on `943`. The shared port prompt in `lib/common.sh` only accepts ports `1024–65535`, so `943` would be a default it then rejects. Nothing but a human ever types this port; client profiles carry the VPN port, never the web UI's.

### Changing settings later

Edit `~/docker/openvpn/.env` and rerun `deploy.sh`. Every setting it manages is re-applied on each run, so this is the supported way to change the endpoint, the ports, or the memory cap:

```bash
nano ~/docker/openvpn/.env    # e.g. change VPN_HOST=
bash deploy.sh
```

---

## 👤 First Login

Username **`openvpn`**, password from the secrets file:

```bash
cat ~/docker/openvpn/.openvpn-docker-secrets.txt
```

Then open the **admin** UI at `/admin`:

- Via NPM: `https://your-domain/admin`
- Via the direct host port: `https://<server-ip>:9443/admin`

> 📌 Access Server also auto-generates its own password on first boot and prints it to the container log. `deploy.sh` overwrites it with the generated one above, so the log's password is already stale — use the secrets file. (If you ever need the original: `docker logs openvpn-as | grep -i "auto-generated pass"`.)

### Adding VPN users

In the admin UI: **User Management → User Permissions** → add a username → **Save** → **Update Running Server**.

Users then get their own profile from the **client portal** (the same address *without* `/admin`), signing in with their own credentials. The `.ovpn` file they download already contains your endpoint and certificates.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Scheme**: `https` ← **not** `http`
   - **Forward Hostname/IP**: `openvpn-as`
   - **Forward Port**: `943`
3. Enable **SSL** with Let's Encrypt from the UI.

> ⚠️ **The Scheme dropdown is the one thing people miss here.** Access Server terminates TLS itself on 943 with a self-signed certificate — it does not serve plain HTTP. Leave the scheme on `http` and NPM gets a TLS handshake where it expected a plain response, which surfaces as a **502 Bad Gateway**. NPM does not verify the upstream's self-signed certificate, so no extra config is needed beyond setting the scheme.

No custom nginx block is required for this service — unlike [NetBird](../netbird/) or [OpenProject](../../Projects/openproject/), a plain Proxy Host is enough.

✅ No web-UI host port is published by default — NPM reaches the container by name over `main-net`. `1194/udp` is separate, always published, and does not go through NPM.

---

## 🔍 Verifying It Works

The web UI loading tells you nothing about whether the tunnel is reachable — those are two different ports and two different protocols. Check the tunnel separately:

```bash
# On the server: is the daemon actually listening on UDP 1194?
sudo ss -ulnp | grep 1194
```

```bash
# From outside the network: is the port open from the internet?
nc -zvu your-domain 1194
```

If the first succeeds and the second doesn't, the container is fine and the problem is your router's port-forward or a cloud firewall/security group — not this deployment.

---

## 🛠️ Management Commands

```bash
cd ~/docker/openvpn
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f openvpn-as` | Follow the server's logs |
| `docker compose pull && docker compose up -d` | Update to the latest image |

Access Server's own CLI, `sacli`, is what `deploy.sh` uses under the hood and is available for anything the web UI doesn't expose:

```bash
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli ConfigQuery
```

> ⚠️ Changes made with `sacli ConfigPut` need `sacli start` afterwards to take effect. Note also that `deploy.sh` re-applies its own settings (`host.name`, daemon ports, admin password) on every run — if you change one of those by hand, rerunning `deploy.sh` will put it back. Change `.env` instead.

---

## 💾 Backups

This repo's **Backup** option covers OpenVPN fully: the PKI, the user database, and all server config live in the `openvpn_openvpn-as-data` volume, and `.env` sits in the install directory. Both are captured by the generic backup, so no special `backup.sh` is needed.

⚠️ The volume contains your certificate authority. Restoring `.env` without it — or vice versa — gives you a server that can't authenticate any existing client profile.

---

## 📌 Notes & Deviations

- **Access Server, not a plain OpenVPN image.** Plain OpenVPN has no web UI and no user management; certificates are handled by hand with `easy-rsa`. The community wrappers that add a UI are all in poor shape: [`kylemanna/openvpn`](https://hub.docker.com/r/kylemanna/openvpn)'s image was last built in **2020**, and [`d3vilh/openvpn-server`](https://hub.docker.com/r/d3vilh/openvpn-server)'s in **December 2024**. For a VPN, where the entire value proposition is a current crypto stack, a years-old image is the wrong default. `openvpn/openvpn-as` is the only option that is both official and actively rebuilt — the 2-connection limit is the price, and it's stated up front rather than buried.
- **Port 443 is not published.** Upstream's own example publishes it for OpenVPN-over-TCP, but NGINX Proxy Manager owns 80/443 in this repo — publishing it would make the stack fail to start on a port conflict. The TCP daemon is off by default; `deploy.sh` offers it on a non-conflicting port instead.
- **One daemon per protocol, pinned.** Access Server defaults to one daemon *per CPU core*, and multi-daemon mode places each on a **consecutive** port — 1194, 1195, 1196… on a 4-core box. Only 1194 is published, so the extras would be unreachable and profiles could name a port that never answers. `deploy.sh` pins `n_daemons` to 1 so what's published and what's advertised stay identical.
- **The admin password is generated, not grepped from the log.** Upstream's documented flow is to read the auto-generated password out of the container log. `deploy.sh` sets its own with `sacli SetLocalPassword` instead, so this service matches every other one here: credentials come from the deploy script and land in the secrets file.
- **A named volume, not a bind mount.** Access Server stores its PKI and user database under `/openvpn` owned by uids internal to the container.

---

## 📜 License

OpenVPN Access Server is **proprietary software** with its own [end user license agreement](https://openvpn.net/as-docs/eula.html) — unlike most services in this repo, it is not open source, and the 2-connection free tier is a license grant rather than a technical limit. This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
