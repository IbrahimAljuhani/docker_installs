# 🔑 Vaultwarden

Deploys [Vaultwarden](https://github.com/dani-garcia/vaultwarden) — a lightweight, Bitwarden-compatible password manager server — behind the shared `main-net` network so [NGINX Proxy Manager](../../../README.md) can front it.

It speaks the official Bitwarden API, so the official Bitwarden apps and browser extensions work against it unchanged. Single container, SQLite embedded — one of the lightest services in this repo.

See the top of [`docker-compose.yml`](docker-compose.yml) for the exact, deliberate deviations from upstream's own example.

---

## 🔐 This One Holds Your Passwords — Read This

Everything in this repo is worth securing, but this service *is* the security. Three things are not optional:

1. **HTTPS is mandatory in practice.** Browser password managers and 2FA/WebAuthn registration simply refuse to operate over plain `http://`. A direct host port is fine for a first look; put it behind NPM with SSL before storing anything real.
2. **Close registration immediately after creating your account** — see [below](#-required-close-registration-after-your-first-account). Open signups on a reachable instance means strangers can register on your password manager.
3. **`DOMAIN` must be correct.** It's not cosmetic: attachments, WebAuthn/2FA, and emailed links are all built from it.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows, it installs the full bundle automatically (skipping anything already installed).

### 2. Deploy Vaultwarden

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Security/vaultwarden/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Security/vaultwarden/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

This is a **single-instance** service: one Vaultwarden deployment per host, under `~/docker/vaultwarden/`.

`deploy.sh` generates a random admin-page password and stores it as an **Argon2 hash** in `.env` (using Vaultwarden's own `hash --preset owasp` command), while the plaintext you actually type goes to `~/docker/vaultwarden/.vaultwarden-docker-secrets.txt` (`600`).

> 💡 If hashing isn't available in your Vaultwarden version, `deploy.sh` falls back to a plaintext token rather than failing the whole deploy, and tells you it did. Vaultwarden accepts both. To upgrade later, see [Re-hashing the admin token](#-re-hashing-the-admin-token).

You'll also be asked whether to cap memory on the `vaultwarden` container (default suggestion: `512m`) and whether to publish a host port for direct access without NPM (default suggestion: `8222`, default answer no).

---

## 🚨 REQUIRED: Close Registration After Your First Account

`deploy.sh` sets `SIGNUPS_ALLOWED=true` so you can create your own account. **Close it the moment you have:**

```bash
sed -i 's/^SIGNUPS_ALLOWED=true/SIGNUPS_ALLOWED=false/' ~/docker/vaultwarden/.env
cd ~/docker/vaultwarden && docker compose up -d
```

To invite others afterward, use the admin page (`/admin`) or an organization invite — neither requires reopening public signups.

---

## 👤 First Login & the Admin Page

Vaultwarden has **no default account**. Visit the site and register your own — the first account is just a normal user account.

The **admin page** at `/admin` is separate: it manages users, invites, and server settings, and is protected by the admin token (not by any user account). Log in with the plaintext password from the secrets file.

> 📌 Don't need it? Deleting the `ADMIN_TOKEN` line from `.env` and restarting **disables the admin page entirely** — a legitimate and safer choice if you're the only user.

---

## 🌐 Reverse Proxy (NGINX Proxy Manager)

1. Open `http://<server-ip>:81`
2. Create a **Proxy Host**:
   - **Domain**: your chosen domain, e.g. `vault.example.com` (must match `DOMAIN` in `.env`)
   - **Forward Hostname/IP**: `vaultwarden-app`
   - **Forward Port**: `80`
   - Enable **Websockets Support** (used for live sync between your devices)
3. Enable **SSL** with Let's Encrypt from the UI — see the warning at the top of this README; this is effectively required, not optional.

✅ No host port is published for `vaultwarden-app` by default — NPM reaches it by container name over `main-net`.

> 📌 **Older guides mention a second port `3012` for websockets.** That's obsolete — current Vaultwarden serves websockets on the main port, enabled by default. One Proxy Host to port `80` is all you need.

---

## 💾 Backups

This repo's **Backup** option (in `services.sh`) fully covers Vaultwarden: everything — vault data, attachments, config — lives in the single `/data` volume with an embedded SQLite database, which the generic volume backup captures completely. No special `backup.sh` is needed here, unlike the Postgres/MySQL-backed services.

Given what this service stores, take backups **before** upgrades, and keep at least one copy off this host.

---

## 🛠️ Management Commands

```bash
cd ~/docker/vaultwarden
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check container status |
| `docker compose logs -f vaultwarden` | Follow the app's logs |
| `docker compose stop` / `start` | Stop/start without removing containers |
| `docker compose pull && docker compose up -d` | Update to the latest image |

### 🔁 Re-hashing the admin token

If your token was stored as plaintext (the fallback path), you can replace it with an Argon2 hash at any time:

```bash
docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp
```

Copy the `$argon2id$...` string it prints into `~/docker/vaultwarden/.env` as:

```
ADMIN_TOKEN='$argon2id$...'
```

Keep the **single quotes** and the **single `$`** characters exactly as printed — this file is passed to the container via `env_file`, so no `$`-doubling is needed (and doubling them would break it). Then `docker compose up -d`.

---

## 📌 Notes & Deviations

- **Container port is `80`**, despite upstream's `.env.template` showing `ROCKET_PORT=8000` — that value is the bare binary's default, and the official Docker image overrides it (`ROCKET_PORT=80` + `EXPOSE 80` in its own Dockerfile).
- **`env_file` instead of `${VAR}` substitution**, deliberately: the Argon2 admin token is full of `$` characters that Compose would otherwise try to expand as variables. This is the same class of problem as this repo's [WireGuard](../../VPN/wireguard/) service, solved the opposite way there (`$$`-doubling) because that one genuinely needs substitution.
- **No private `<service>-net`** — single container, no database to isolate, so it joins `main-net` directly (same as Jellyfin/LinkStack).
- Upstream's own example publishes a host port unconditionally; here that's optional (default: no), matching this repo's "NPM-only unless you opt in" convention.

---

## 📜 License

Vaultwarden itself is licensed separately (AGPL-3.0 — see the [official repository](https://github.com/dani-garcia/vaultwarden) for terms). It is an independent, unofficial implementation and is **not** affiliated with or endorsed by Bitwarden, Inc. This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
