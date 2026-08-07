# ☁️ ownCloud Infinite Scale

Deploys [ownCloud Infinite Scale](https://owncloud.com/infinite-scale/) (oCIS) — file sync and share — behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

**One container.** No database, no Redis, no PHP: oCIS is a single Go binary with its storage engine, metadata store and identity provider all embedded. That makes it the lightest storage service in this repo by a wide margin.

Verified against upstream's own [`ocis_full` deployment example](https://github.com/owncloud/ocis/blob/master/deployments/examples/ocis_full/ocis.yml). See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations.

---

## 📗 Infinite Scale, not ownCloud Server (Classic)

ownCloud ships two products, and this is the newer one. If you expected the familiar PHP ownCloud with its app store, that's **Classic** (now at version 11) and this isn't it.

The choice wasn't close:

- **Upstream calls Classic a migration path, not a destination.** Their own wording is that no major new features are being built on that codebase, and that it's kept "secure, supported and compliant while people plan their migration."
- **Classic would have duplicated [Nextcloud](../nextcloud/).** Same architecture — PHP + MariaDB + Redis — for a near-identical feature set. Infinite Scale is genuinely different, so the catalogue gains an option instead of a synonym.

**What you give up:** no PHP app ecosystem, and a different sharing and user model (oCIS uses "Spaces" rather than Classic's folder-based shares). If you need a specific ownCloud Classic app, use Nextcloud instead — its app store is the closest equivalent still under active development.

> 📌 There's also **[OpenCloud](https://github.com/opencloud-eu/opencloud)**, a community fork of oCIS started by former ownCloud developers after the Kiteworks acquisition. It's very active, but it isn't ownCloud, so it isn't what this service deploys.

---

## ⚠️ Read This Before Deploying

**oCIS fetches its own public URL, from inside the container.**

Its embedded identity provider verifies every access token by requesting `https://your-domain/.well-known/openid-configuration` — as an outbound HTTP call **from the container**, not from your browser. So the container has to be able to resolve *and reach* your public domain.

On a home or LAN server whose router doesn't hairpin, that call fails, and the symptom is nasty because it looks like something else entirely: **the site loads perfectly and login fails**, with `failed to verify access token … connection refused` buried in the logs. It's reported upstream over and over — issues [#6357](https://github.com/owncloud/ocis/issues/6357), [#6612](https://github.com/owncloud/ocis/issues/6612), [#7438](https://github.com/owncloud/ocis/issues/7438), [#10446](https://github.com/owncloud/ocis/issues/10446) are all this one problem.

**`deploy.sh` handles it for you.** Upstream's example solves it by giving the Traefik container a Docker network alias equal to the public domain, so oCIS's DNS lookup lands on the proxy container. That option isn't open to us — NGINX Proxy Manager is core infrastructure created by `install_dockhub.sh`, not a container this compose file manages. Instead `deploy.sh` writes an `extra_hosts` entry into `docker-compose.override.yml`:

```yaml
extra_hosts:
  - "your-domain:host-gateway"
```

That points the domain at the Docker host, where NPM is listening on 443 and answers with the correct certificate. Same effect as upstream's alias, achieved from our side.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows.

### 2. Deploy oCIS

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Storage/owncloud/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Storage/owncloud/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service, under `~/docker/owncloud/`.

| Question | Notes |
|---|---|
| Memory limit | Optional, suggested `1g`. |
| Host port | Optional, default `9200` (oCIS's own port). |
| **Domain** | Asked only if you said **no** to a host port. |

`deploy.sh` generates the admin password into `.env` (`600`) and `~/docker/owncloud/.owncloud-docker-secrets.txt` (`600`).

### The two access paths differ in more than the URL

| | Host port | Behind NPM |
|---|---|---|
| `OCIS_URL` | `https://<ip>:9200` | `https://your-domain` |
| `PROXY_TLS` | `true` — oCIS serves its own cert | `false` — NPM terminates TLS |
| `OCIS_INSECURE` | `true` — accepts its own self-signed cert | `false` |
| `extra_hosts` | not needed | domain → `host-gateway` |

> 📌 **Even the direct host port uses https**, with a self-signed certificate and a browser warning. That isn't a stylistic choice: oCIS's web UI is an OIDC client, and browsers only expose the crypto APIs it needs in a [secure context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts). Plain http can't work — the same constraint that made [Vaultwarden](../../Security/vaultwarden/) NPM-only in this repo.

To switch from a host port to NPM later, edit `OCIS_URL`, `PROXY_TLS`, `OCIS_INSECURE` and `OCIS_DOMAIN` in `~/docker/owncloud/.env`, then rerun `deploy.sh`.

---

## 👤 First Login

Username **`admin`**, password from the secrets file:

```bash
cat ~/docker/owncloud/.owncloud-docker-secrets.txt
```

Demo users are deliberately **off** (`IDM_CREATE_DEMO_USERS=false`) — upstream's demo accounts ship with published passwords.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: the domain you gave `deploy.sh`
   - **Forward Hostname/IP**: `owncloud-ocis`
   - **Forward Port**: `9200`
   - Enable **Websockets Support**
3. Enable **SSL** with Let's Encrypt from the UI.

Scheme stays `http` — with `PROXY_TLS=false`, oCIS serves plain HTTP inside the network and NPM terminates TLS.

✅ No host port is published by default.

---

## 🩺 Site loads but login fails

This is *the* oCIS symptom, and it is almost always the self-URL lookup described above. Check the logs first:

```bash
cd ~/docker/owncloud && docker compose logs ocis | grep -i 'verify access token'
```

A hit there confirms it. Then verify the `extra_hosts` entry actually made it in:

```bash
docker inspect owncloud-ocis --format '{{json .HostConfig.ExtraHosts}}'
```

You should see your domain mapped to an IP. If it's empty, `OCIS_DOMAIN` is unset in `.env` — set it and rerun `deploy.sh`.

Other things worth checking, in order:

| Check | Rules out |
|---|---|
| `docker compose logs ocis \| tail -30` | oCIS itself failing to start |
| `OCIS_URL` in `.env` exactly matches the browser URL, scheme included | The commonest misconfiguration |
| `PROXY_TLS=false` when behind NPM | A protocol mismatch that shows as 502 |

> ⚠️ **Changing `OCIS_URL` after users exist** invalidates issued tokens — everyone gets logged out and has to sign in again. Harmless, but alarming if unexpected.

---

## 🛠️ Management Commands

```bash
cd ~/docker/owncloud
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check the container |
| `docker compose logs -f ocis` | Follow the logs |
| `docker compose pull && docker compose up -d` | Update to the latest patch of the pinned version |

> 💡 **Upgrading across major versions**: bump `OCIS_VERSION` in `.env`, then `docker compose up -d`. oCIS migrates its own store on start. **Back up both volumes first** — oCIS does not support downgrading, so a failed upgrade is only recoverable from a backup.

---

## 💾 Backups

The repo's generic **Backup** covers oCIS correctly, and no `backup.sh` override is needed: there's no separate database container to dump, so the two named volumes are the whole story.

🔐 **Both volumes must be restored together.** `ocis-config` holds the secrets oCIS generated on first start — the JWT signing key and the machine auth key — and `ocis-data` holds every uploaded file. Restoring the data without the matching config leaves it unreadable. Those secrets are **not** in the secrets file, because oCIS generates them itself inside the container, which is exactly why the volume backup is the only copy.

---

## 📌 Notes & Deviations

- **No Traefik.** Upstream's example bundles it with its own Let's Encrypt; it would collide with NGINX Proxy Manager on 80/443.
- **Only the variables a single container needs.** Upstream also sets `GATEWAY_GRPC_ADDR`, `MICRO_REGISTRY_ADDRESS`, `NATS_*` and `PROXY_CSP_CONFIG_FILE_LOCATION` — those exist so separate Collabora / OnlyOffice / Tika containers can reach oCIS's internals. None of those are deployed here, and carrying the settings without them would be cargo cult.
- **`ocis init || true`** is upstream's own idiom, not a shortcut: `init` generates the config and its random secrets, then fails on every later run because the file exists. The command uses `exec ocis server` so the process receives signals directly and `docker compose stop` doesn't fall back to SIGKILL.
- **Generated admin password**; upstream's example falls back to literal `admin`.
- **No office integration.** Collabora and OnlyOffice are separate deployments in upstream's example and would each be their own service here.

---

## 📜 License

ownCloud Infinite Scale is licensed separately (Apache-2.0 — see the [official repository](https://github.com/owncloud/ocis)). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
