#!/bin/bash
# deploy.sh (services/Web/linkstack)
# Purpose: Deploy LinkStack (single container, SQLite embedded — see
# docker-compose.yml for the deliberate deviations from upstream's own
# docker-compose example).
#
# This is a single-instance service: one LinkStack deployment per host,
# under ~/docker/linkstack/.

set -euo pipefail

if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Deploy LinkStack behind the shared 'main-net' network."
            exit 0
            ;;
    esac
fi

if [[ $EUID -eq 0 ]]; then
    echo "This script must NOT be run as root. Please run as a regular user in the docker group." >&2
    exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/docker/linkstack"
LOGFILE="$INSTALL_DIR/deploy.log"

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
    prompt_mem_limit "linkstack" "512m"
    prompt_host_port "8095"

    # HTTP_SERVER_NAME/HTTPS_SERVER_NAME are Apache's ServerName for each
    # vhost — not security-critical here (LinkStack has no CORS/host-header
    # check like Vikunja/Plane), but should still match how you access it so
    # any auto-generated links are correct. Derive from the host port when
    # chosen, otherwise ask for the real domain — same pattern as this
    # repo's other services.
    if [[ -n "$HOST_PORT" ]]; then
        SERVER_IP_FOR_NAME=$(hostname -I 2>/dev/null | awk '{print $1}')
        [[ -z "${SERVER_IP_FOR_NAME:-}" ]] && SERVER_IP_FOR_NAME="localhost"
        SERVER_NAME_VALUE="$SERVER_IP_FOR_NAME"
        print_info "Using '$SERVER_NAME_VALUE' as the server name. Once you switch to NPM, edit SERVER_NAME in .env to your real domain."
    else
        read -rp "Enter the public domain you'll point NGINX Proxy Manager at (e.g. links.example.com): " LINKSTACK_DOMAIN
        [[ -n "$LINKSTACK_DOMAIN" ]] || print_error "A domain is required."
        SERVER_NAME_VALUE="$LINKSTACK_DOMAIN"
    fi

    cat > "$INSTALL_DIR/.env" <<EOF
LINKSTACK_VERSION=latest
TZ=UTC
SERVER_ADMIN=admin@localhost
SERVER_NAME=$SERVER_NAME_VALUE
EOF
    [[ -n "$MEM_LIMIT" ]] && echo "MEM_LIMIT=$MEM_LIMIT" >> "$INSTALL_DIR/.env"
    [[ -n "$HOST_PORT" ]] && echo "HOST_PORT=$HOST_PORT" >> "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"
    print_info "Generated .env at $INSTALL_DIR/.env."
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
        echo "  linkstack:"
        [[ -n "$ENV_MEM_LIMIT" ]] && echo "    mem_limit: $ENV_MEM_LIMIT"
        if [[ -n "$ENV_HOST_PORT" ]]; then
            echo "    ports:"
            echo "      - \"$ENV_HOST_PORT:80\""
        fi
    } > "$INSTALL_DIR/docker-compose.override.yml"
    [[ -n "$ENV_MEM_LIMIT" ]] && print_info "Memory limit $ENV_MEM_LIMIT applied to the 'linkstack' container."
    [[ -n "$ENV_HOST_PORT" ]] && print_info "Host port $ENV_HOST_PORT published for direct access (plain HTTP — avoids the container's self-signed HTTPS cert for a quick test)."
else
    rm -f "$INSTALL_DIR/docker-compose.override.yml"
fi

print_info "Starting LinkStack..."
(cd "$INSTALL_DIR" && $COMPOSE_CMD up -d 2>&1 | tee -a "$LOGFILE") \
    || print_error "Failed to start LinkStack. Check log: $LOGFILE"

print_info "LinkStack is starting."
echo
echo "──────────────────────────────────────────────"
if [[ -n "$ENV_HOST_PORT" ]]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "${SERVER_IP:-}" ]] && SERVER_IP="<your-server-ip>"
    echo "🌐 URL:          http://$SERVER_IP:$ENV_HOST_PORT"
fi
echo "🔗 Proxy target: linkstack-app:443 (HTTPS, self-signed) on 'main-net'"
echo "👤 First visit:  follow the setup wizard — create your own admin account"
echo "📜 Log:          $LOGFILE"
echo "──────────────────────────────────────────────"
echo
echo "Set up NGINX Proxy Manager: forward to linkstack-app, port 443,"
echo "forward scheme HTTPS (not HTTP — LinkStack's container terminates its"
echo "own self-signed TLS on 443; proxying plain HTTP to port 80 causes"
echo "mixed-content errors per upstream's own docs). Enable SSL on the NPM"
echo "side too. See the README's Reverse Proxy section."
print_tunnel_reminder_if_relevant
echo
echo "To manage: cd $INSTALL_DIR && $COMPOSE_CMD [ps|logs -f|stop|restart]"
