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

print_info()  { echo -e "[✓] $1" >&2; }
print_warn()  { echo -e "[!] $1" >&2; }
print_error() { echo -e "[✗] $1" >&2; exit 1; }

check_prerequisites() {
    local missing=()
    command -v docker &>/dev/null || missing+=("Docker CE")
    if docker compose version &>/dev/null; then
        COMPOSE_CMD="docker compose"
    elif docker-compose version &>/dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        missing+=("Docker Compose")
    fi
    if (( ${#missing[@]} != 0 )); then
        print_error "Missing required components: ${missing[*]}. Run install_dockhub.sh first."
    fi
}

valid_mem_limit() { [[ "$1" =~ ^[0-9]+[bkmgBKMG]?$ ]]; }

# Prompts once for an optional memory cap on the container. Sets MEM_LIMIT
# in the caller's shell (no command substitution — keeps the prompt on a
# real terminal instead of risking it being swallowed into a captured value).
MEM_LIMIT=""
prompt_mem_limit() {
    local default="$1" answer value
    read -rp "Set a memory limit for the 'linkstack' container? (y/N): " answer
    [[ "${answer,,}" == "y" ]] || return 0
    while true; do
        read -rp "Memory limit (default: $default, e.g. 256m, 512m): " value
        value="${value:-$default}"
        if valid_mem_limit "$value"; then
            MEM_LIMIT="$value"
            return 0
        fi
        echo "Invalid format — use a number followed by b/k/m/g (e.g. 512m)." >&2
    done
}

valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 >= 1024 && 10#$1 <= 65535 )); }

port_in_use() {
    local port="$1"
    if command -v ss &>/dev/null; then
        ss -tuln 2>/dev/null | grep -q ":$port\b"
    elif command -v netstat &>/dev/null; then
        netstat -tuln 2>/dev/null | grep -q ":$port\b"
    else
        return 1
    fi
}

# Prompts once for an optional host port (direct access without NPM, e.g. for
# quick testing). Maps to the container's plain-HTTP port 80 — not 443 —
# specifically so a quick test doesn't hit LinkStack's self-signed HTTPS
# cert. Sets HOST_PORT in the caller's shell (no command substitution — same
# reasoning as prompt_mem_limit above).
HOST_PORT=""
prompt_host_port() {
    local default="$1" answer port cont
    read -rp "Also publish a host port for direct access without NPM (e.g. http://<server-ip>:<port>)? (y/N): " answer
    [[ "${answer,,}" == "y" ]] || return 0
    while true; do
        read -rp "Host port (default: $default): " port
        port="${port:-$default}"
        if ! valid_port "$port"; then
            echo "Invalid port — must be a number between 1024 and 65535." >&2
            continue
        fi
        if port_in_use "$port"; then
            read -rp "Port $port looks already in use — continue anyway? (y/N): " cont
            [[ "${cont,,}" == "y" ]] || continue
        fi
        HOST_PORT="$port"
        return 0
    done
}

check_prerequisites

mkdir -p "$INSTALL_DIR"

# Shared reverse-proxy network (created by install_dockhub.sh; created here
# too, idempotently, so this script also works standalone/out of order).
if ! docker network ls --format '{{.Name}}' | grep -qx "main-net"; then
    docker network create main-net || true
    if docker network ls --format '{{.Name}}' | grep -qx "main-net"; then
        print_info "Created docker network 'main-net'."
    else
        print_error "Failed to create docker network 'main-net'."
    fi
fi

if [[ -f "$INSTALL_DIR/.env" ]]; then
    print_info "Existing deployment found at $INSTALL_DIR — reusing its .env (not regenerated)."
else
    prompt_mem_limit "512m"
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
echo
echo "To manage: cd $INSTALL_DIR && $COMPOSE_CMD [ps|logs -f|stop|restart]"
