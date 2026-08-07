# 🕸️ NetBird

Deploys [NetBird](https://netbird.io/) (a WireGuard-based overlay network — peers connect to each other directly, with NAT traversal handled for you) behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

Two containers: `netbird-dashboard` (web UI) and `netbird-server` (management + signal + relay + STUN, combined upstream since v0.65).

---

## ⚠️ Read This Before Deploying

NetBird has two hard requirements that most services here don't. Neither is optional, and both will look like "it deployed fine" until peers fail to connect.

**1. NPM needs a custom routing block — a default Proxy Host is not enough.**
NetBird speaks gRPC and WebSocket alongside plain HTTP. Point a normal Proxy Host at it and the dashboard loads, you can even sign in — and then peers silently fail to register. See [Reverse Proxy](#-reverse-proxy-nginx-proxy-manager) for the exact config.

**2. UDP port 3478 must be reachable from the internet.**
That's STUN, and NAT traversal is the entire point of the product. It's raw UDP: **no HTTP reverse proxy can carry it, and neither can Cloudflare Tunnel.** If your server is behind a home router, you need a port-forward for `3478/udp` — exactly like this repo's [WireGuard](../wireguard/) service needs one for `51820/udp`.

> 💡 **Running everything through Cloudflare Tunnel?** The dashboard and API will work through the tunnel, but STUN will not. Peers on the same LAN may still connect; peers across different networks generally won't. A direct port-forward for `3478/udp` is the fix.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows.

### 2. Deploy NetBird

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/VPN/netbird/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/VPN/netbird/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service, under `~/docker/netbird/`. You'll be asked for your public domain (required) and whether to cap memory on `netbird-server` (default: no).

**There's no host-port option**, same as this repo's [Vaultwarden](../../Security/vaultwarden/) and for a similar reason: NetBird builds its OAuth redirect URIs, its gRPC endpoint, and the dashboard's API endpoint from the domain. Reaching it at `http://<ip>:<port>` would break the login flow outright, so the domain is always required.

### Generated files, not just `.env`

Unlike every other service here, `deploy.sh` writes several files into `~/docker/netbird/`:

| File | What it's for |
|---|---|
| `.env` | Compose-level values (image tags, domain, secrets) |
| `config.yaml` | The server: STUN, auth issuer, trusted proxies, SQLite encryption |
| `dashboard.env` | The web UI: API endpoints and OAuth settings |
| `npm-custom-nginx.conf` | The routing block to paste into NPM — `cat` it and copy |
| `verify-npm.sh` | One-command check that NPM routing actually works |

`config.yaml` and `dashboard.env` are **derived from `.env` and rewritten on every run**. So to change the domain: edit `NETBIRD_DOMAIN` in `.env`, then rerun `deploy.sh` — editing those two directly gets overwritten.

---

## 👤 First Login

NetBird has **no default account and no admin password**. It ships an embedded [Dex](https://dexidp.io/) identity provider, so you just open the dashboard and sign up — **the first account created becomes the admin**.

The secrets file holds server-side keys (relay auth, datastore encryption, session cookie), not login credentials.

> 🔐 Sign up promptly after deploying. Until you do, the first person who reaches the dashboard becomes your admin.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: the domain you gave `deploy.sh`
   - **Forward Hostname/IP**: `netbird-dashboard`
   - **Forward Port**: `80`
3. **SSL tab** → enable Let's Encrypt **and turn on "HTTP/2 Support"**. This one isn't cosmetic: gRPC runs over HTTP/2, and without it peer registration fails.
4. **Custom Nginx Configuration** → paste the routing block. It sends the non-dashboard paths to `netbird-server` — API, OAuth, WebSocket relay, and native gRPC.

   `deploy.sh` already wrote it to a file for you, so you don't have to copy it out of this page:

   ```bash
   cat ~/docker/netbird/npm-custom-nginx.conf
   ```

   > ⚠️ **Where to paste it:** depending on your NPM version this is either a tab labelled **Advanced**, or — in current versions — the **⚙️ gear icon** at the top-right of the *Edit Proxy Host* dialog, next to the `Details / Custom Locations / SSL` tabs. It opens a box titled **"Custom Nginx Configuration"**. It is *not* the "Custom Locations" tab.

   <details>
   <summary>The block itself, if you'd rather copy it from here</summary>

```nginx
# Required for long-lived connections (gRPC and WebSocket)
client_header_timeout 1d;
client_body_timeout 1d;

# WebSocket connections (relay, signal, management)
location ~ ^/(relay|ws-proxy/) {
    proxy_pass http://netbird-server:80;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 1d;
}

# Native gRPC (signal + management)
location ~ ^/(signalexchange\.SignalExchange|management\.ManagementService)/ {
    grpc_pass grpc://netbird-server:80;
    grpc_read_timeout 1d;
    grpc_send_timeout 1d;
    grpc_socket_keepalive on;
}

# HTTP routes (API + OAuth2)
location ~ ^/(api|oauth2)/ {
    proxy_pass http://netbird-server:80;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

   </details>

This block is upstream's own — it's what their setup script emits when you choose "Nginx Proxy Manager" as the reverse proxy.

### ✅ Verify the routing actually took effect

Don't judge this by whether the dashboard loads — it loads either way. `deploy.sh` writes a check script for exactly this:

```bash
bash ~/docker/netbird/verify-npm.sh
```

It runs the request below and explains the result, so you don't have to interpret it:

```bash
curl -sk -o /dev/null -w '%{http_code} %{content_type}\n' \
  https://your-domain/oauth2/.well-known/openid-configuration
```

| Result | Meaning |
|---|---|
| `200 application/json` | ✅ Routing is correct — `/oauth2` reaches `netbird-server`. |
| `404 text/html` | ❌ The routing block is missing or wrong. `/oauth2` is still hitting `netbird-dashboard`, which only serves static files — this is what produces **"Oops, something went wrong — Error: Unauthenticated"** at login. |

If it returns 404, confirm the block actually reached NPM — don't rely on remembering. Read NPM's own generated config:

```bash
conf=$(docker exec npm-app-1 sh -c 'grep -l "your-domain" /data/nginx/proxy_host/*.conf')
docker exec npm-app-1 grep -c "netbird-server" "$conf"   # 0 = block not applied
docker exec npm-app-1 grep -c "http2"          "$conf"   # 0 = HTTP/2 not enabled
```

If `netbird-server` counts 0, the block isn't saved — check you used the **⚙️ Custom Nginx Configuration** box (see the warning in step 4), not the "Custom Locations" tab.

### 🧹 Once it returns 200, open the dashboard in a private window

**Do this even if you're sure the page is broken.** The dashboard keeps OAuth
state in the browser's `localStorage`, and every failed attempt while the
routing was wrong leaves stale state behind. That state survives a normal
reload, so the page keeps showing the old **"Error: Unauthenticated"** long
after the server side is fixed — making a successful repair look like another
failure.

`curl` returning `200 application/json` is the authoritative signal, not the
page. When it does, open the site in a **private/incognito window**. If it
works there, go back to your normal window and clear this site's data.

### 🩺 Diagnosing in the right order

If something is wrong, work outwards from the server — each step rules out one
layer, so you never guess:

| # | Check | Rules out |
|---|---|---|
| 1 | `docker logs netbird-server \| grep "Dex IDP initialized"` — should show `https://your-domain/oauth2` | The server and its generated `config.yaml` |
| 2 | Read NPM's generated config (command above) | Whether the routing block actually saved |
| 3 | `curl` the OIDC endpoint (command above) | Whether routing works end to end |
| 4 | Open in a private window | Browser cache vs. a real server problem |

Steps 1–3 all pass but the page still errors? It's step 4 — the browser, not
the deployment.

To confirm the server itself is healthy independently of NPM:

```bash
docker logs netbird-server | grep -i "Dex IDP initialized"
```

It should print the issuer as `https://your-domain/oauth2`. If that line looks right, any remaining problem is in NPM, not in this deployment.

✅ No HTTP host port is published — NPM reaches both containers by name over `main-net`. `3478/udp` is separate and always published; it does not go through NPM.

---

## 🛠️ Management Commands

```bash
cd ~/docker/netbird
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f netbird-server` | Follow the server's logs |
| `docker compose logs -f dashboard` | Follow the web UI's logs |
| `docker compose pull && docker compose up -d` | Update to the latest images |

> 🩺 **Dashboard loads but peers won't connect?** That's almost always the NPM custom nginx block missing, HTTP/2 not enabled, or `3478/udp` unreachable — in that order.

---

## 💾 Backups

This repo's **Backup** option covers NetBird fully: the SQLite store lives in the `netbird_data` volume, and `.env` / `config.yaml` / `dashboard.env` sit in the install directory. Both are captured by the generic backup, so no special `backup.sh` is needed.

⚠️ `DATASTORE_ENCRYPTION_KEY` encrypts that store. A backup restored **without** the matching key in `.env` is unreadable — keep the secrets file with your backups.

---

## 📌 Notes & Deviations

- **No bundled Traefik.** Upstream's default setup runs Traefik on host ports 80/443 with its own Let's Encrypt, which would collide with NGINX Proxy Manager. Upstream supports this directly — their script's option `[3] Nginx Proxy Manager` drops Traefik and routes by container name over an external network, which is what `main-net` is here.
- **Reproduced statically from a generator.** Upstream ships no static compose file; a ~55 KB interactive script generates one. This service is the "NPM + external network" branch of that script's output, written out as normal files so it fits this repo's curl-and-run model. If NetBird changes that layout upstream, this is the first place to check.
- **`trustedHTTPProxies` is discovered, not hardcoded.** `deploy.sh` reads `main-net`'s actual subnet so NetBird accepts `X-Forwarded-*` from NPM. Upstream's script hardcodes its Traefik IP there, which would be wrong for this setup. Same class of setting as Jellyfin's "Known proxies" and AdGuard's `trusted_proxies`.
- **No host-port option** — the second service here without one, after Vaultwarden. The domain is load-bearing for OAuth and gRPC, so an IP:port path can't work.
- **Embedded Dex, no external IdP.** NetBird can integrate with Google/Microsoft/Okta/Keycloak; this deploy uses its built-in identity provider so it works standalone. Configuring an external IdP is upstream territory.

---

## 📜 License

NetBird itself is licensed separately (BSD-3-Clause, with some enterprise features under a commercial license — see the [official repository](https://github.com/netbirdio/netbird)). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
