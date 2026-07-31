#!/bin/bash
# deploy.sh (services/redmine)
# Purpose: Deploy the Redmine stack (app, db) — see docker-compose.yml for
# the full stack and the deliberate deviations from the official redmine
# Docker Hub image's own docker-compose example.
#
# This is a single-instance service: one Redmine deployment per host, under
# ~/docker/redmine/.

set -euo pipefail

if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Deploy the Redmine stack behind the shared 'main-net' network."
            exit 0
            ;;
    esac
fi

if [[ $EUID -eq 0 ]]; then
    echo "This script must NOT be run as root. Please run as a regular user in the docker group." >&2
    exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/docker/redmine"
LOGFILE="$INSTALL_DIR/deploy.log"
SECRETS_FILE="$INSTALL_DIR/.redmine-docker-secrets.txt"

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
    command -v openssl &>/dev/null || missing+=("openssl")
    if (( ${#missing[@]} != 0 )); then
        print_error "Missing required components: ${missing[*]}. Run install_docker_core.sh first."
    fi
}

generate_secret() {
    local raw
    raw=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9')
    echo "${raw:0:20}"
}

valid_mem_limit() { [[ "$1" =~ ^[0-9]+[bkmgBKMG]?$ ]]; }

# Prompts once for an optional memory cap on the main container only ('db'
# stays unbounded). Sets MEM_LIMIT in the caller's shell (no command
# substitution — keeps the prompt on a real terminal instead of risking it
# being swallowed into a captured value).
MEM_LIMIT=""
prompt_mem_limit() {
    local default="$1" answer value
    read -rp "Set a memory limit for the 'redmine' container? (y/N): " answer
    [[ "${answer,,}" == "y" ]] || return 0
    while true; do
        read -rp "Memory limit (default: $default, e.g. 512m, 1g): " value
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
# quick testing). Sets HOST_PORT in the caller's shell (no command
# substitution — same reasoning as prompt_mem_limit above). Unlike
# openproject/nextcloud/n8n/taiga, choosing this does NOT require flipping
# any HTTPS/trusted-host setting — Redmine doesn't force either (see
# docker-compose.yml's header comment for how that was verified).
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

# Shared reverse-proxy network (created by install_docker_core.sh; created here
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
    POSTGRES_PASSWORD=$(generate_secret)
    SECRET_KEY_BASE=$(generate_secret)
    prompt_mem_limit "512m"
    prompt_host_port "3000"

    cat > "$INSTALL_DIR/.env" <<EOF
REDMINE_VERSION=6-alpine
POSTGRES_USER=redmine
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=redmine
SECRET_KEY_BASE=$SECRET_KEY_BASE
EOF
    [[ -n "$MEM_LIMIT" ]] && echo "MEM_LIMIT=$MEM_LIMIT" >> "$INSTALL_DIR/.env"
    [[ -n "$HOST_PORT" ]] && echo "HOST_PORT=$HOST_PORT" >> "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"

    {
        echo "# Auto-generated Redmine secrets - DO NOT SHARE"
        echo "$(date '+%F %T')"
        echo "  POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
        echo "  SECRET_KEY_BASE=$SECRET_KEY_BASE"
    } > "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    print_info "Generated .env and saved a copy of the secrets to $SECRETS_FILE."
fi

if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    print_info "Existing docker-compose.yml found at $INSTALL_DIR — keeping it (not overwritten). Delete it yourself first if you want the latest version from this repo."
else
    cp "$SOURCE_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml"
fi

# Bind-mount targets for plugins/themes — created explicitly (and owned by
# the invoking user) so Docker doesn't create them as root on first 'up -d'.
mkdir -p "$INSTALL_DIR/plugins" "$INSTALL_DIR/themes"

# docker-compose.override.yml is fully owned by this script (never hand-edit
# it), so it's always safe to regenerate from whatever .env currently has.
ENV_MEM_LIMIT=""
ENV_HOST_PORT=""
grep -q '^MEM_LIMIT=' "$INSTALL_DIR/.env" 2>/dev/null && ENV_MEM_LIMIT=$(grep '^MEM_LIMIT=' "$INSTALL_DIR/.env" | cut -d= -f2)
grep -q '^HOST_PORT=' "$INSTALL_DIR/.env" 2>/dev/null && ENV_HOST_PORT=$(grep '^HOST_PORT=' "$INSTALL_DIR/.env" | cut -d= -f2)

if [[ -n "$ENV_MEM_LIMIT" || -n "$ENV_HOST_PORT" ]]; then
    {
        echo "services:"
        echo "  redmine:"
        [[ -n "$ENV_MEM_LIMIT" ]] && echo "    mem_limit: $ENV_MEM_LIMIT"
        if [[ -n "$ENV_HOST_PORT" ]]; then
            echo "    ports:"
            echo "      - \"$ENV_HOST_PORT:3000\""
        fi
    } > "$INSTALL_DIR/docker-compose.override.yml"
    [[ -n "$ENV_MEM_LIMIT" ]] && print_info "Memory limit $ENV_MEM_LIMIT applied to the 'redmine' container (db stays unbounded)."
    [[ -n "$ENV_HOST_PORT" ]] && print_info "Host port $ENV_HOST_PORT published for direct access."
else
    rm -f "$INSTALL_DIR/docker-compose.override.yml"
fi

print_info "Starting Redmine..."
(cd "$INSTALL_DIR" && $COMPOSE_CMD up -d 2>&1 | tee -a "$LOGFILE") \
    || print_error "Failed to start Redmine. Check log: $LOGFILE"

print_info "Redmine is starting."
echo
echo "──────────────────────────────────────────────"
if [[ -n "$ENV_HOST_PORT" ]]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "${SERVER_IP:-}" ]] && SERVER_IP="<your-server-ip>"
    echo "🌐 URL:          http://$SERVER_IP:$ENV_HOST_PORT"
fi
echo "🔗 Proxy target: redmine-app:3000 on 'main-net'"
echo "👤 First login:  admin / admin — change this immediately (My account → Change password)"
echo "📜 Log:          $LOGFILE"
[[ -f "$SECRETS_FILE" ]] && echo "🔒 Secrets:      $SECRETS_FILE"
echo "──────────────────────────────────────────────"
echo
echo "Set up NGINX Proxy Manager: forward to redmine-app:3000, enable SSL."
echo "Then set your real URL from inside Redmine itself: Administration ->"
echo "Settings -> General -> \"Host name and path\" (used for links in emails) —"
echo "unlike this repo's other services, Redmine has no deploy-time domain"
echo "setting; it's entirely configured from its own admin UI after login."
echo
echo "To manage: cd $INSTALL_DIR && $COMPOSE_CMD [ps|logs -f|stop|restart]"
