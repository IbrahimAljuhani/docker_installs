#!/bin/bash
# deploy.sh (services/ERP/erpnext)
# Purpose: Deploy ERPNext (Frappe) — see docker-compose.yml for the full
# 11-container stack, why each container exists, and the deliberate
# deviations from Frappe's own compose.yaml / pwd.yml.
#
# This is a single-instance service (unlike services/ERP/odoo, which supports
# multiple named instances): one ERPNext deployment per host, under
# ~/docker/erpnext/.

set -euo pipefail

if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Deploy the ERPNext stack behind the shared 'main-net' network."
            exit 0
            ;;
    esac
fi

if [[ $EUID -eq 0 ]]; then
    echo "This script must NOT be run as root. Please run as a regular user in the docker group." >&2
    exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/docker/erpnext"
LOGFILE="$INSTALL_DIR/deploy.log"
SECRETS_FILE="$INSTALL_DIR/.erpnext-docker-secrets.txt"

# Shared helpers — sourced from a git checkout if present, self-fetched
# otherwise so standalone curl usage still works with no extra steps.
LIB_COMMON="$SOURCE_DIR/../../../lib/common.sh"
if [[ ! -f "$LIB_COMMON" ]]; then
    LIB_COMMON="$(mktemp -d)/common.sh"
    curl -fsSL -o "$LIB_COMMON" "https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/lib/common.sh"
fi
# shellcheck source=/dev/null
source "$LIB_COMMON"

check_prerequisites

mkdir -p "$INSTALL_DIR"

ensure_main_net

if [[ -f "$INSTALL_DIR/.env" ]]; then
    print_info "Existing deployment found at $INSTALL_DIR — reusing its .env (not regenerated)."
else
    print_warn "ERPNext is the heaviest service in this repo: 11 containers."
    print_warn "4 GB RAM is a realistic floor, 8 GB is comfortable. First-run site"
    print_warn "creation compiles assets and takes 5-15 minutes."
    echo

    # Frappe is multi-tenant and resolves which site to serve from the HTTP
    # Host header, so the site's NAME must be the domain it's reached at.
    # That makes this question unavoidable and unconditional — unlike most
    # services here, there's no "skip the domain if you only want a host
    # port" path, because the site has to be named something at creation
    # time and renaming a Frappe site afterwards is a manual chore.
    echo "ERPNext names its site after the domain you'll serve it on — Frappe picks"
    echo "the site from the Host header, so the two have to match."
    read -rp "Enter the domain for this ERPNext site (e.g. erp.example.com): " SITE_NAME_VALUE
    validate_domain "$SITE_NAME_VALUE" "site domain"

    DB_PASSWORD=$(generate_secret 24)
    ADMIN_PASSWORD=$(generate_secret 20)
    prompt_mem_limit "erpnext-backend" "2g"
    prompt_host_port "8085"

    # NPM reaches the frontend from main-net, so trust that subnet as the
    # real-IP source — discovered rather than hardcoded, since Docker
    # assigns it. Without it, every login record and audit-log entry in the
    # ERP shows NPM's container IP instead of the actual user's.
    TRUSTED_CIDR=$(docker network inspect main-net --format '{{ (index .IPAM.Config 0).Subnet }}' 2>/dev/null || true)
    if [[ -z "$TRUSTED_CIDR" ]]; then
        TRUSTED_CIDR="127.0.0.1"
        print_warn "Couldn't read main-net's subnet; leaving UPSTREAM_REAL_IP_ADDRESS at $TRUSTED_CIDR. If ERPNext later logs every user's IP as the proxy's, set it correctly in .env and rerun."
    fi

    cat > "$INSTALL_DIR/.env" <<EOF
ERPNEXT_VERSION=v16.31.1
SITE_NAME=$SITE_NAME_VALUE
DB_PASSWORD=$DB_PASSWORD
ADMIN_PASSWORD=$ADMIN_PASSWORD
UPSTREAM_REAL_IP_ADDRESS=$TRUSTED_CIDR
EOF
    [[ -n "$MEM_LIMIT" ]] && echo "MEM_LIMIT=$MEM_LIMIT" >> "$INSTALL_DIR/.env"
    [[ -n "$HOST_PORT" ]] && echo "HOST_PORT=$HOST_PORT" >> "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"

    {
        echo "# Auto-generated ERPNext secrets - DO NOT SHARE"
        echo "$(date '+%F %T'): site=$SITE_NAME_VALUE"
        echo "  ERPNext login:      Administrator"
        echo "  ERPNext password:   $ADMIN_PASSWORD"
        echo "  MariaDB root pass:  $DB_PASSWORD"
    } > "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    print_info "Generated .env and saved a copy of the secrets to $SECRETS_FILE."
fi

if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    print_info "Existing docker-compose.yml found at $INSTALL_DIR — keeping it (not overwritten). Delete it yourself first if you want the latest version from this repo."
else
    cp "$SOURCE_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml"
fi

ENV_MEM_LIMIT=$(read_env_value "MEM_LIMIT" "$INSTALL_DIR/.env")
ENV_HOST_PORT=$(read_env_value "HOST_PORT" "$INSTALL_DIR/.env")
ENV_SITE_NAME=$(read_env_value "SITE_NAME" "$INSTALL_DIR/.env")
ENV_ADMIN_PASSWORD=$(read_env_value "ADMIN_PASSWORD" "$INSTALL_DIR/.env")

# docker-compose.override.yml is fully owned by this script (never hand-edit
# it), so it's always safe to regenerate from whatever .env currently has.
# The memory cap goes on 'backend' only — the workers, db and redis stay
# unbounded, same "main container only" convention every other service here
# follows.
if [[ -n "$ENV_MEM_LIMIT" || -n "$ENV_HOST_PORT" ]]; then
    {
        echo "services:"
        if [[ -n "$ENV_MEM_LIMIT" ]]; then
            echo "  backend:"
            echo "    mem_limit: $ENV_MEM_LIMIT"
        fi
        if [[ -n "$ENV_HOST_PORT" ]]; then
            echo "  frontend:"
            echo "    ports:"
            echo "      - \"$ENV_HOST_PORT:8080\""
        fi
    } > "$INSTALL_DIR/docker-compose.override.yml"
    [[ -n "$ENV_MEM_LIMIT" ]] && print_info "Memory limit $ENV_MEM_LIMIT applied to the 'erpnext-backend' container (workers/db/redis stay unbounded)."
    [[ -n "$ENV_HOST_PORT" ]] && print_info "Host port $ENV_HOST_PORT published for direct access."
else
    rm -f "$INSTALL_DIR/docker-compose.override.yml"
fi

print_info "Starting ERPNext (first run pulls several images — this takes a while)..."
(cd "$INSTALL_DIR" && $COMPOSE_CMD up -d 2>&1 | tee -a "$LOGFILE") \
    || print_error "Failed to start ERPNext. Check log: $LOGFILE"

# ── Wait for site creation ──────────────────────────────────────────────
# `bench new-site` runs in the one-shot create-site container: it creates the
# database, installs the erpnext app and builds assets. On a first run that
# is genuinely 5-15 minutes, and until it finishes the site returns errors —
# so this waits rather than printing a "done" that isn't true yet.
echo
print_info "Creating the ERPNext site '$ENV_SITE_NAME'. This is the slow part."
print_info "Watch it live in another terminal if you like:"
print_info "  cd $INSTALL_DIR && $COMPOSE_CMD logs -f create-site"
echo

SITE_READY=0
WAITED=0
while (( WAITED < 1800 )); do
    # `docker exec` against the fixed container_name rather than `compose
    # exec`: no dependency on the compose file's service naming, no TTY
    # allocation, and it behaves the same on docker-compose v1 and v2.
    # WORKDIR in the image is /home/frappe/frappe-bench, so this path is the
    # same relative one upstream's own create-site guard uses.
    if docker exec erpnext-backend test -d "sites/$ENV_SITE_NAME" 2>/dev/null; then
        SITE_READY=1
        break
    fi
    # Surface a hard failure immediately instead of waiting out the full 30
    # minutes: once create-site has exited non-zero, nothing will change.
    CREATE_EXIT=$(docker inspect erpnext-create-site --format '{{.State.Status}}:{{.State.ExitCode}}' 2>/dev/null || true)
    if [[ "$CREATE_EXIT" == exited:* && "$CREATE_EXIT" != "exited:0" ]]; then
        print_error "Site creation failed (${CREATE_EXIT#exited:} was the exit code). See what went wrong with: cd $INSTALL_DIR && $COMPOSE_CMD logs create-site"
    fi
    sleep 15
    WAITED=$(( WAITED + 15 ))
    if (( WAITED % 120 == 0 )); then
        print_info "Still building... ($(( WAITED / 60 )) min elapsed)"
    fi
done

if (( SITE_READY )); then
    print_info "Site '$ENV_SITE_NAME' created."
    # Frappe builds absolute URLs (password-reset links, notification emails,
    # PDF asset paths) from host_name. Left unset it guesses from the request
    # and can emit http:// links for an https:// site.
    docker exec erpnext-backend \
        bench --site "$ENV_SITE_NAME" set-config host_name "https://$ENV_SITE_NAME" >/dev/null 2>&1 \
        || print_warn "Couldn't set host_name automatically — if emailed links come out as http://, run: docker exec erpnext-backend bench --site $ENV_SITE_NAME set-config host_name https://$ENV_SITE_NAME"
else
    print_warn "Site creation hasn't finished after 30 minutes."
    print_warn "It may still be running. Check with:"
    print_warn "  cd $INSTALL_DIR && $COMPOSE_CMD logs -f create-site"
fi

echo
echo "──────────────────────────────────────────────"
if [[ -n "$ENV_HOST_PORT" ]]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "${SERVER_IP:-}" ]] && SERVER_IP="<your-server-ip>"
    echo "🌐 URL (direct):  http://$SERVER_IP:$ENV_HOST_PORT"
fi
echo "🌐 URL (via NPM): https://$ENV_SITE_NAME"
echo "🔗 Proxy target:  erpnext-frontend:8080 on 'main-net'"
echo "👤 Login:         Administrator / the generated password below"
echo "📜 Log:           $LOGFILE"
[[ -f "$SECRETS_FILE" ]] && echo "🔒 Secrets:       $SECRETS_FILE"
echo "──────────────────────────────────────────────"
echo
echo "Set up NGINX Proxy Manager:"
echo "   1. Forward to  erpnext-frontend : 8080  + enable 'Websockets Support'"
echo "   2. Enable SSL with Let's Encrypt"
echo
echo "⚠️  The domain MUST be $ENV_SITE_NAME — Frappe picks the site from the"
echo "   Host header, so a different domain returns 'Site not found'."
print_tunnel_reminder_if_relevant
echo
echo "To manage: cd $INSTALL_DIR && $COMPOSE_CMD [ps|logs -f|stop|restart]"
