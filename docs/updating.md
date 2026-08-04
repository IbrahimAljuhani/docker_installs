# 🔄 Updating DockHub

Two separate things can be "updated": the DockHub repo itself (scripts, new services, docs), and an individual service's own container image. They're independent.

---

## Updating the DockHub repo itself

If you cloned the repo (the recommended install method):

```bash
cd dockhub
git pull
```

That's it — `git pull` is sufficient. Nothing else needs to run. Specifically:

- **Already-deployed services are untouched.** Every `deploy.sh` refuses to overwrite an existing `docker-compose.yml` under `~/docker/<service>/`, so pulling newer template files from the repo doesn't change anything already running. If you want a service to pick up template changes (a fixed bug, a new option), delete its `docker-compose.yml`/`docker-compose.override.yml` under `~/docker/<service>/` yourself first, then rerun `deploy.sh` — this reuses your existing `.env` (secrets, domain, etc.) and just re-copies the compose file.
- **New services become available immediately.** `services.sh`'s `CATALOG` array and each service's folder come from the repo — a `git pull` that adds a new service means it just works the next time you run `services.sh`, no extra step.
- **`lib/common.sh` changes take effect the next time any `deploy.sh` runs**, since it's sourced fresh each time (not copied anywhere persistent).

If you only curled `install_dockhub.sh` standalone (no git clone), there's no "repo" to update locally — each script self-fetches the current version of anything it needs (like `lib/common.sh`) from GitHub on every run anyway. Re-run the same `curl` command to get the latest `install_dockhub.sh`/`services.sh` if you want the newest menu/prompts.

---

## Updating a single service's container image

This is separate from updating DockHub itself — it means pulling a newer version of the actual application (Jellyfin, Vikunja, etc.), not this repo's scripts.

```bash
cd ~/docker/<service>
docker compose pull && docker compose up -d
```

This works for every service. A few have their own additional in-app update mechanism on top of this (documented in that service's own README if so — e.g. LinkStack has a one-click updater in its Admin Panel).

For multi-instance services (Odoo), run this inside the specific instance's folder: `~/docker/odoo/<instance-name>/`.

---

## Updating core infrastructure (NPM, Portainer)

```bash
sudo bash install_dockhub.sh
```

Pick **"Install / manage core infrastructure"** — if NPM/Portainer are already running, you're offered a **Reset** option that recreates just those two containers (never touches Docker Engine, `main-net`, or any other service) and asks separately whether to wipe their data. Say no to data-wiping if you just want a fresh container with the same config/certs/settings.
