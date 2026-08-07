#!/bin/bash
# deploy.sh (services/Security/vaultwarden)
# Purpose: Deploy Vaultwarden (Bitwarden-compatible password manager) — see
# docker-compose.yml for the deliberate deviations from upstream's own
# example, especially why env_file is used instead of ${VAR} substitution.
#
# This is a single-instance service: one Vaultwarden deployment per host,
# under ~/docker/vaultwarden/.

set -euo pipefail

if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Deploy Vaultwarden behind the shared 'main-net' network."
            exit 0
            ;;
    esac
fi

if [[ $EUID -eq 0 ]]; then
    echo "This script must NOT be run as root. Please run as a regular user in the docker group." >&2
    exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/docker/vaultwarden"
LOGFILE="$INSTALL_DIR/deploy.log"
SECRETS_FILE="$INSTALL_DIR/.vaultwarden-docker-secrets.txt"
VAULTWARDEN_IMAGE="vaultwarden/server:latest"

# Shared helpers — sourced from a git checkout if present, self-fetched
# otherwise so standalone curl usage still works with no extra steps.
LIB_COMMON="$SOURCE_DIR/../../../lib/common.sh"
if [[ ! -f "$LIB_COMMON" ]]; then
    LIB_COMMON="$(mktemp -d)/common.sh"
    curl -fsSL -o "$LIB_COMMON" "https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/lib/common.sh"
fi
# shellcheck source=/dev/null
source "$LIB_COMMON"

# Turns a plaintext admin password into the Argon2 PHC hash Vaultwarden
# recommends storing instead of the raw token, using the binary's own
# `hash` subcommand inside a throwaway container.
#
# Deliberately defensive: that subcommand prompts for the password twice on
# a TTY, and whether it accepts piped stdin can change between releases. If
# anything goes wrong — command missing, no output, output that isn't a PHC
# string — we fall back to storing the plaintext token, which Vaultwarden
# still accepts. A working deploy with a slightly weaker token beats a
# deploy that dies on an upstream CLI change (see this repo's WireGuard
# service, where exactly that happened with wg-easy's `wgpw`).
#
# Sets ADMIN_TOKEN_STORED (what goes in .env) and TOKEN_IS_HASHED (1/0).
ADMIN_TOKEN_STORED=""
TOKEN_IS_HASHED=0
hash_admin_token() {
    local plain="$1" out=""
    print_info "Hashing the admin token (pulls the Vaultwarden image if needed)..."
    out=$(printf '%s\n%s\n' "$plain" "$plain" \
        | docker run --rm -i "$VAULTWARDEN_IMAGE" /vaultwarden hash --preset owasp 2>/dev/null \
        | grep -oE '\$argon2id\$[^[:space:]'"'"'"]+' | head -1) || true

    if [[ -n "$out" ]]; then
        ADMIN_TOKEN_STORED="$out"
        TOKEN_IS_HASHED=1
        return 0
    fi

    ADMIN_TOKEN_STORED="$plain"
    TOKEN_IS_HASHED=0
    print_warn "Couldn't produce an Argon2 hash (upstream's 'hash' subcommand may need a TTY in this version). Falling back to a plaintext admin token — still valid, just less protected at rest. To upgrade it later, see this service's README."
    return 0
}

check_prerequisites

mkdir -p "$INSTALL_DIR"

ensure_main_net

if [[ -f "$INSTALL_DIR/.env" ]]; then
    print_info "Existing deployment found at $INSTALL_DIR — reusing its .env (not regenerated)."
else
    prompt_mem_limit "vaultwarden" "512m"
    prompt_host_port "8222"

    # DOMAIN must match how you actually reach Vaultwarden — it's not
    # cosmetic here: attachments, WebAuthn/2FA registration, and emailed
    # links are all built from it. Same derivation pattern as this repo's
    # Vikunja/PhotoPrism.
    if [[ -n "$HOST_PORT" ]]; then
        SERVER_IP_FOR_URL=$(hostname -I 2>/dev/null | awk '{print $1}')
        [[ -z "${SERVER_IP_FOR_URL:-}" ]] && SERVER_IP_FOR_URL="localhost"
        DOMAIN_VALUE="http://$SERVER_IP_FOR_URL:$HOST_PORT"
        print_warn "Using '$DOMAIN_VALUE' as DOMAIN for now. Browser password managers and 2FA/WebAuthn require HTTPS — plain http:// is fine for a first look, but switch DOMAIN to your real https:// domain in .env before storing anything real."
    else
        read -rp "Enter the public domain you'll point NGINX Proxy Manager at (e.g. vault.example.com): " VAULTWARDEN_DOMAIN
        [[ -n "$VAULTWARDEN_DOMAIN" ]] || print_error "A domain is required — Vaultwarden builds attachment, 2FA, and email links from it."
        DOMAIN_VALUE="https://$VAULTWARDEN_DOMAIN"
    fi

    ADMIN_PASSWORD=$(generate_secret)
    hash_admin_token "$ADMIN_PASSWORD"

    # Single-quoted on purpose: the Argon2 hash is full of '$' and this file
    # is consumed via env_file (not ${...} substitution) — see
    # docker-compose.yml's header comment.
    cat > "$INSTALL_DIR/.env" <<EOF
VAULTWARDEN_VERSION=latest
DOMAIN=$DOMAIN_VALUE
ADMIN_TOKEN='$ADMIN_TOKEN_STORED'
SIGNUPS_ALLOWED=true
EOF
    [[ -n "$MEM_LIMIT" ]] && echo "MEM_LIMIT=$MEM_LIMIT" >> "$INSTALL_DIR/.env"
    [[ -n "$HOST_PORT" ]] && echo "HOST_PORT=$HOST_PORT" >> "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"

    {
        echo "# Auto-generated Vaultwarden secrets - DO NOT SHARE"
        echo "$(date '+%F %T'): domain=$DOMAIN_VALUE"
        echo "  Admin page password: $ADMIN_PASSWORD"
        if (( TOKEN_IS_HASHED )); then
            echo "  (stored in .env as an Argon2 hash — this plaintext is the one you type)"
        else
            echo "  (stored in .env as PLAINTEXT — hashing was unavailable; see README to upgrade)"
        fi
    } > "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    print_info "Generated .env and saved a copy of the secrets to $SECRETS_FILE."
fi

if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    print_info "Existing docker-compose.yml found at $INSTALL_DIR — keeping it (not overwritten). Delete it yourself first if you want the latest version from this repo."
else
    cp "$SOURCE_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml"
fi

# docker-compose.override.yml is fully owned by this script (never hand-edit
# it), so it's always safe to regenerate from whatever .env currently has.
ENV_MEM_LIMIT=""
ENV_HOST_PORT=""
grep -q '^MEM_LIMIT=' "$INSTALL_DIR/.env" 2>/dev/null && ENV_MEM_LIMIT=$(grep '^MEM_LIMIT=' "$INSTALL_DIR/.env" | cut -d= -f2)
grep -q '^HOST_PORT=' "$INSTALL_DIR/.env" 2>/dev/null && ENV_HOST_PORT=$(grep '^HOST_PORT=' "$INSTALL_DIR/.env" | cut -d= -f2)

if [[ -n "$ENV_MEM_LIMIT" || -n "$ENV_HOST_PORT" ]]; then
    {
        echo "services:"
        echo "  vaultwarden:"
        [[ -n "$ENV_MEM_LIMIT" ]] && echo "    mem_limit: $ENV_MEM_LIMIT"
        if [[ -n "$ENV_HOST_PORT" ]]; then
            echo "    ports:"
            echo "      - \"$ENV_HOST_PORT:80\""
        fi
    } > "$INSTALL_DIR/docker-compose.override.yml"
    [[ -n "$ENV_MEM_LIMIT" ]] && print_info "Memory limit $ENV_MEM_LIMIT applied to the 'vaultwarden' container."
    [[ -n "$ENV_HOST_PORT" ]] && print_info "Host port $ENV_HOST_PORT published for direct access."
else
    rm -f "$INSTALL_DIR/docker-compose.override.yml"
fi

print_info "Starting Vaultwarden..."
(cd "$INSTALL_DIR" && $COMPOSE_CMD up -d 2>&1 | tee -a "$LOGFILE") \
    || print_error "Failed to start Vaultwarden. Check log: $LOGFILE"

print_info "Vaultwarden is starting."
echo
echo "──────────────────────────────────────────────"
if [[ -n "$ENV_HOST_PORT" ]]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "${SERVER_IP:-}" ]] && SERVER_IP="<your-server-ip>"
    echo "🌐 URL:          http://$SERVER_IP:$ENV_HOST_PORT"
fi
echo "🔗 Proxy target: vaultwarden-app:80 on 'main-net'"
echo "👤 First visit:  create your own account — Vaultwarden has no default user"
echo "🔐 Admin page:   /admin  (password in the secrets file below)"
echo "📜 Log:          $LOGFILE"
[[ -f "$SECRETS_FILE" ]] && echo "🔒 Secrets:      $SECRETS_FILE"
echo "──────────────────────────────────────────────"
echo
echo "🚨 REQUIRED NEXT STEP — open registration is currently ON so you can"
echo "   create your own account. As soon as you have, close it:"
echo "     sed -i 's/^SIGNUPS_ALLOWED=true/SIGNUPS_ALLOWED=false/' $INSTALL_DIR/.env"
echo "     cd $INSTALL_DIR && $COMPOSE_CMD up -d"
echo "   Leaving it open means anyone who can reach this instance can sign"
echo "   up on your password manager."
echo
echo "Set up NGINX Proxy Manager: forward to vaultwarden-app, port 80,"
echo "enable Websockets Support, enable SSL. HTTPS isn't optional here —"
echo "browser password managers and 2FA/WebAuthn refuse to work without it."
print_tunnel_reminder_if_relevant
echo
echo "To manage: cd $INSTALL_DIR && $COMPOSE_CMD [ps|logs -f|stop|restart]"
