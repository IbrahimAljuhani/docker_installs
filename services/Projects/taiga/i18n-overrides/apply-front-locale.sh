#!/bin/sh
# Runs automatically inside the taiga-front container via nginx's official
# /docker-entrypoint.d/ mechanism (any executable *.sh dropped there runs
# before nginx starts — Taiga's own Dockerfile already uses this same
# mechanism for docker/config_env_subst.sh).
#
# taiga-front bundles its built assets under a version-hashed subdirectory
# (e.g. /usr/share/nginx/html/v-<hash>/locales/taiga/locale-ar.json) that
# changes with every taiga-front release, so the real path can't be hardcoded
# — this searches for it at container startup instead.

set -e

SRC="/custom-i18n/locale-ar.json"
[ -f "$SRC" ] || exit 0

TARGET=$(find /usr/share/nginx/html -type f -path '*/locales/taiga/locale-ar.json' 2>/dev/null | head -n1)

if [ -n "$TARGET" ]; then
    cp "$SRC" "$TARGET"
    echo "[taiga-i18n-overrides] Applied community Arabic frontend translation to $TARGET"
else
    echo "[taiga-i18n-overrides] WARNING: locale-ar.json not found under /usr/share/nginx/html — skipping override" >&2
fi
