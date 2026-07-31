# Community Arabic translation overlay

Upstream Taiga's official Arabic translation (managed via [Weblate](https://hosted.weblate.org/projects/taiga/)) was largely incomplete at the time these files were produced — ~91% of `taiga-front` UI strings and ~80% of `taiga-back` backend strings fell back to English. These files are a community-contributed completion of that translation, submitted upstream to Weblate, and bundled here so anyone deploying this repo's Taiga service gets the benefit immediately instead of waiting for Taiga's next Docker image release.

## Files

- `django-ar.po` — completed `taiga-back` (Django) translation, gettext source format. Compiled into `django.mo` automatically by `deploy.sh` at deploy time (see below) — the published `taigaio/taiga-back` image strips out the `gettext`/`msgfmt` tools after its own build step, so it can't compile a `.po` file itself at runtime.
- `locale-ar.json` — completed `taiga-front` translation, used directly (no compilation needed).
- `apply-front-locale.sh` — runs automatically inside the `taiga-front` container via nginx's official `/docker-entrypoint.d/` startup-script mechanism, and copies `locale-ar.json` over the real (version-hashed) path inside the image.

## How this gets applied

Opt-in only, asked once on first deploy ("Apply the community Arabic translation overlay?"). If enabled, `deploy.sh`:
1. Compiles `django-ar.po` → `django.mo` using a throwaway `alpine` container (needs internet access to pull `alpine:3` and install `gettext` — one-time, cached afterward unless `django-ar.po` changes).
2. Mounts `django.mo` read-only into both `taiga-back` and `taiga-async` (same image, same locale path).
3. Mounts `locale-ar.json` and `apply-front-locale.sh` into `taiga-front`.

None of this touches the upstream Docker images — it's all volume mounts layered on top via `docker-compose.override.yml`, so a fresh `docker compose pull` still gets you Taiga's latest code, just with these two translation files overlaid.

## This is a snapshot, not a live sync

These files reflect the state of the Arabic Weblate translation as of **2026-07-31**. They will NOT automatically pick up further improvements made on Weblate (by this contributor or anyone else) after that date, and upstream's own translation will keep improving over time and eventually surpass the need for this overlay entirely.

To refresh:
1. Download the latest translated files for `ar` from the [Weblate project](https://hosted.weblate.org/projects/taiga/) (`taiga-back` component → `django.po`, `taiga-front` component → `locale-ar.json`).
2. Replace `django-ar.po` and `locale-ar.json` in this directory with the fresh copies.
3. Delete the cached `~/docker/taiga/i18n-overrides/django.mo` on your server (or just delete the whole `~/docker/taiga/i18n-overrides/` directory) and rerun `deploy.sh` — it recompiles automatically since the `.po` source will be newer than any leftover `.mo`.

## Disabling later

Edit `AR_I18N_OVERLAY=false` (or delete the line) in `~/docker/taiga/.env`, then rerun `deploy.sh`.
