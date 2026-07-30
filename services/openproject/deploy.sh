#!/bin/bash
# deploy.sh (services/openproject)
# Purpose: Deploy the OpenProject stack (web, worker, cron, seeder, db, cache,
# hocuspocus) — see docker-compose.yml for the full stack and the deliberate
# deviations from the official opf/openproject-docker-compose repo.
#
# This is a single-instance service (unlike services/odoo, which supports
# multiple named instances): one OpenProject deployment per host, under
# ~/docker/openproject/.

set -euo pipefail

if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Deploy the OpenProject stack behind the shared 'main-net' network."
            exit 0
            ;;
    esac
fi

if [[ $EUID -eq 0 ]]; then
    echo "This script must NOT be run as root. Please run as a regular user in the docker group." >&2
    exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/docker/openproject"
LOGFILE="$INSTALL_DIR/deploy.log"
SECRETS_FILE="$INSTALL_DIR/.openproject-docker-secrets.txt"

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
    # $1 = number of random bytes (hex-encoded, so output is 2x this length)
    openssl rand -hex "$1"
}

valid_mem_limit() { [[ "$1" =~ ^[0-9]+[bkmgBKMG]?$ ]]; }

# Prompts once for an optional memory cap on the main container only (db,
# cache, worker, cron, seeder, hocuspocus stay unbounded). Sets MEM_LIMIT in
# the caller's shell (no command substitution — keeps the prompts on a real
# terminal instead of risking them being swallowed into a captured value).
MEM_LIMIT=""
prompt_mem_limit() {
    local default="$1" answer value
    read -rp "Set a memory limit for the 'web' container? (y/N): " answer
    [[ "${answer,,}" == "y" ]] || return 0
    while true; do
        read -rp "Memory limit (default: $default, e.g. 2g, 512m): " value
        value="${value:-$default}"
        if valid_mem_limit "$value"; then
            MEM_LIMIT="$value"
            return 0
        fi
        echo "Invalid format — use a number followed by b/k/m/g (e.g. 2g)." >&2
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
# substitution — same reasoning as prompt_mem_limit above). Note: only the
# 'web' container is reachable this way — the /hocuspocus real-time editing
# path needs NPM's routing and won't work over a bare host port.
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
    print_warn "OpenProject needs at least 4 GB RAM / 2 CPU cores / 20 GB disk for a small team — more for heavier use."
    read -rp "Enter the public domain you'll point NGINX Proxy Manager at (e.g. openproject.example.com): " HOST_NAME
    [[ -n "$HOST_NAME" ]] || print_error "A host domain is required (used for the collaborative-editing websocket URL)."

    POSTGRES_PASSWORD=$(generate_secret 16)
    SECRET_KEY_BASE=$(generate_secret 64)
    COLLABORATIVE_SERVER_SECRET=$(generate_secret 32)
    prompt_mem_limit "2g"
    prompt_host_port "8080"

    # OPENPROJECT_HTTPS=true makes the app force-redirect to https:// and mark
    # cookies secure-only — correct once NPM/TLS is in front, but it makes a
    # bare-HTTP direct host port completely inaccessible (redirects to a
    # https:// address nothing is listening on). Default it to false only
    # when a host port was chosen; flip it back once NPM/SSL is set up (see
    # README "To change the memory limit later" section for the edit+rerun
    # pattern — same idea, different variable).
    if [[ -n "$HOST_PORT" ]]; then
        OPENPROJECT_HTTPS_VALUE="false"
    else
        OPENPROJECT_HTTPS_VALUE="true"
    fi

    cat > "$INSTALL_DIR/.env" <<EOF
OPENPROJECT_HOST__NAME=$HOST_NAME
OPENPROJECT_HTTPS=$OPENPROJECT_HTTPS_VALUE
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
SECRET_KEY_BASE=$SECRET_KEY_BASE
COLLABORATIVE_SERVER_SECRET=$COLLABORATIVE_SERVER_SECRET
EOF
    [[ -n "$MEM_LIMIT" ]] && echo "MEM_LIMIT=$MEM_LIMIT" >> "$INSTALL_DIR/.env"
    [[ -n "$HOST_PORT" ]] && echo "HOST_PORT=$HOST_PORT" >> "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"

    {
        echo "# Auto-generated OpenProject secrets - DO NOT SHARE"
        echo "$(date '+%F %T'): host=$HOST_NAME"
        echo "  POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
        echo "  SECRET_KEY_BASE=$SECRET_KEY_BASE"
        echo "  COLLABORATIVE_SERVER_SECRET=$COLLABORATIVE_SERVER_SECRET"
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
        echo "  web:"
        [[ -n "$ENV_MEM_LIMIT" ]] && echo "    mem_limit: $ENV_MEM_LIMIT"
        if [[ -n "$ENV_HOST_PORT" ]]; then
            echo "    ports:"
            echo "      - \"$ENV_HOST_PORT:8080\""
        fi
    } > "$INSTALL_DIR/docker-compose.override.yml"
    [[ -n "$ENV_MEM_LIMIT" ]] && print_info "Memory limit $ENV_MEM_LIMIT applied to the 'web' container (db/worker/cron/seeder/hocuspocus stay unbounded)."
    [[ -n "$ENV_HOST_PORT" ]] && print_info "Host port $ENV_HOST_PORT published for direct access (web only — /hocuspocus real-time editing still needs NPM)."
else
    rm -f "$INSTALL_DIR/docker-compose.override.yml"
fi

print_info "Starting OpenProject (first run seeds the database and can take a few minutes)..."
(cd "$INSTALL_DIR" && $COMPOSE_CMD up -d 2>&1 | tee -a "$LOGFILE") \
    || print_error "Failed to start OpenProject. Check log: $LOGFILE"

print_info "OpenProject is starting."
echo
echo "──────────────────────────────────────────────"
if [[ -n "$ENV_HOST_PORT" ]]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "${SERVER_IP:-}" ]] && SERVER_IP="<your-server-ip>"
    echo "🌐 URL:                     http://$SERVER_IP:$ENV_HOST_PORT"
fi
echo "🔗 Proxy target (main):     openproject-app:8080 on 'main-net'"
echo "🔗 Proxy target (realtime): openproject-hocuspocus:1234 at path /hocuspocus on 'main-net'"
echo "👤 First login:             admin / admin — you'll be forced to change it immediately"
echo "📜 Log:                     $LOGFILE"
[[ -f "$SECRETS_FILE" ]] && echo "🔒 Secrets:                 $SECRETS_FILE"
echo "──────────────────────────────────────────────"
echo
if [[ -n "$ENV_HOST_PORT" ]]; then
    echo "⚠️  OPENPROJECT_HTTPS was set to false for this plain-http:// direct port"
    echo "   to work at all. Real-time collaborative editing still needs NPM's"
    echo "   /hocuspocus routing regardless. Once you switch to NPM+SSL, edit"
    echo "   OPENPROJECT_HTTPS=true in .env and rerun deploy.sh."
    echo
fi
echo "Set up NGINX Proxy Manager (see README.md 'Reverse Proxy' section for the"
echo "exact Advanced/custom-location config /hocuspocus needs)."
echo
echo "To manage: cd $INSTALL_DIR && $COMPOSE_CMD [ps|logs -f|stop|restart]"
