#!/bin/bash
# deploy.sh (services/taiga)
# Purpose: Deploy the Taiga stack (db, back, async, 2x rabbitmq, front,
# events, protected, gateway) — see docker-compose.yml for the full stack
# and the deliberate deviations from the official taigaio/taiga-docker repo.
#
# This is a single-instance service: one Taiga deployment per host, under
# ~/docker/taiga/.

set -euo pipefail

if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Deploy the Taiga stack behind the shared 'main-net' network."
            exit 0
            ;;
    esac
fi

if [[ $EUID -eq 0 ]]; then
    echo "This script must NOT be run as root. Please run as a regular user in the docker group." >&2
    exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/docker/taiga"
LOGFILE="$INSTALL_DIR/deploy.log"
SECRETS_FILE="$INSTALL_DIR/.taiga-docker-secrets.txt"

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

# Prompts once for an optional memory cap on the main container only
# ('taiga-gateway' — everything else, including the actually memory-hungry
# taiga-back/taiga-async/rabbitmq/postgres, stays unbounded). Sets MEM_LIMIT
# in the caller's shell (no command substitution — keeps the prompt on a
# real terminal instead of risking it being swallowed into a captured value).
MEM_LIMIT=""
prompt_mem_limit() {
    local default="$1" answer value
    read -rp "Set a memory limit for the 'taiga-gateway' container? (y/N): " answer
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
# substitution — same reasoning as prompt_mem_limit above).
HOST_PORT=""

# Checks (against the live DB, not any local marker) whether the 'admin' user
# already exists. Needed because createsuperuser --noinput fails identically
# whether migrations just haven't finished yet or the account is already
# there — this tells the two apart without depending on error-text parsing.
admin_exists() {
    (cd "$INSTALL_DIR" && $COMPOSE_CMD -f docker-compose.yml -f docker-compose-inits.yml run --rm taiga-manage \
        shell -c "from django.contrib.auth import get_user_model; import sys; sys.exit(0 if get_user_model().objects.filter(username='admin').exists() else 1)" \
        >> "$LOGFILE" 2>&1)
}

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

FRESH_DEPLOY=false
if [[ -f "$INSTALL_DIR/.env" ]]; then
    print_info "Existing deployment found at $INSTALL_DIR — reusing its .env (not regenerated)."
else
    FRESH_DEPLOY=true
    print_warn "Taiga needs roughly 4 GB RAM for a small team (Postgres + 2x RabbitMQ + backend workers add up)."

    SECRET_KEY=$(generate_secret)
    POSTGRES_PASSWORD=$(generate_secret)
    RABBITMQ_PASS=$(generate_secret)
    RABBITMQ_ERLANG_COOKIE=$(generate_secret)
    ADMIN_PASSWORD=$(generate_secret)
    prompt_mem_limit "512m"
    prompt_host_port "9000"

    # TAIGA_SCHEME=https (the default) makes the front-end and backend build
    # https:// URLs and the backend validates the Host header against
    # TAIGA_DOMAIN — a placeholder domain wouldn't match a bare IP:port, and
    # https:// URLs are unreachable without NPM/TLS. Default both to the
    # http-safe values only when a host port was chosen; flip them back once
    # NPM/SSL is set up.
    if [[ -n "$HOST_PORT" ]]; then
        TAIGA_SCHEME_VALUE="http"
        WEBSOCKETS_SCHEME_VALUE="ws"
        SERVER_IP_FOR_DOMAIN=$(hostname -I 2>/dev/null | awk '{print $1}')
        [[ -z "${SERVER_IP_FOR_DOMAIN:-}" ]] && SERVER_IP_FOR_DOMAIN="localhost"
        TAIGA_DOMAIN_VALUE="$SERVER_IP_FOR_DOMAIN:$HOST_PORT"
        print_info "Using '$TAIGA_DOMAIN_VALUE' as TAIGA_DOMAIN (must match how you access it). Once you switch to NPM, edit this to your real domain in .env."
    else
        TAIGA_SCHEME_VALUE="https"
        WEBSOCKETS_SCHEME_VALUE="wss"
        read -rp "Enter the public domain you'll point NGINX Proxy Manager at (e.g. taiga.example.com): " TAIGA_DOMAIN_VALUE
        [[ -n "$TAIGA_DOMAIN_VALUE" ]] || print_error "A domain is required (Taiga rejects requests for an unrecognized domain)."
    fi

    cat > "$INSTALL_DIR/.env" <<EOF
TAIGA_SCHEME=$TAIGA_SCHEME_VALUE
TAIGA_DOMAIN=$TAIGA_DOMAIN_VALUE
SUBPATH=
WEBSOCKETS_SCHEME=$WEBSOCKETS_SCHEME_VALUE
SECRET_KEY=$SECRET_KEY
POSTGRES_USER=taiga
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
EMAIL_BACKEND=console
EMAIL_HOST=smtp.host.example.com
EMAIL_PORT=587
EMAIL_HOST_USER=user
EMAIL_HOST_PASSWORD=password
EMAIL_DEFAULT_FROM=changeme@example.com
EMAIL_USE_TLS=True
EMAIL_USE_SSL=False
RABBITMQ_USER=taiga
RABBITMQ_PASS=$RABBITMQ_PASS
RABBITMQ_VHOST=taiga
RABBITMQ_ERLANG_COOKIE=$RABBITMQ_ERLANG_COOKIE
ATTACHMENTS_MAX_AGE=360
ENABLE_TELEMETRY=True
EOF
    [[ -n "$MEM_LIMIT" ]] && echo "MEM_LIMIT=$MEM_LIMIT" >> "$INSTALL_DIR/.env"
    [[ -n "$HOST_PORT" ]] && echo "HOST_PORT=$HOST_PORT" >> "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"

    {
        echo "# Auto-generated Taiga secrets - DO NOT SHARE"
        echo "$(date '+%F %T'): domain=$TAIGA_DOMAIN_VALUE"
        echo "  Admin user:     admin"
        echo "  Admin password: $ADMIN_PASSWORD"
        echo "  SECRET_KEY=$SECRET_KEY"
        echo "  POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
        echo "  RABBITMQ_PASS=$RABBITMQ_PASS"
        echo "  RABBITMQ_ERLANG_COOKIE=$RABBITMQ_ERLANG_COOKIE"
    } > "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    print_info "Generated .env and saved a copy of the secrets to $SECRETS_FILE."
fi

if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    print_info "Existing docker-compose.yml found at $INSTALL_DIR — keeping it (not overwritten). Delete it yourself first if you want the latest version from this repo."
else
    cp "$SOURCE_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml"
    mkdir -p "$INSTALL_DIR/taiga-gateway"
    cp "$SOURCE_DIR/taiga-gateway/taiga.conf" "$INSTALL_DIR/taiga-gateway/taiga.conf"
fi

# Copied independently of docker-compose.yml above: deployments made before
# this file existed have docker-compose.yml already but are still missing
# it, which would otherwise silently break admin-account creation below.
if [[ ! -f "$INSTALL_DIR/docker-compose-inits.yml" ]]; then
    cp "$SOURCE_DIR/docker-compose-inits.yml" "$INSTALL_DIR/docker-compose-inits.yml"
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
        echo "  taiga-gateway:"
        [[ -n "$ENV_MEM_LIMIT" ]] && echo "    mem_limit: $ENV_MEM_LIMIT"
        if [[ -n "$ENV_HOST_PORT" ]]; then
            echo "    ports:"
            echo "      - \"$ENV_HOST_PORT:80\""
        fi
    } > "$INSTALL_DIR/docker-compose.override.yml"
    [[ -n "$ENV_MEM_LIMIT" ]] && print_info "Memory limit $ENV_MEM_LIMIT applied to the 'taiga-gateway' container (everything else stays unbounded)."
    [[ -n "$ENV_HOST_PORT" ]] && print_info "Host port $ENV_HOST_PORT published for direct access."
else
    rm -f "$INSTALL_DIR/docker-compose.override.yml"
fi

print_info "Starting Taiga (first run can take a few minutes to pull 9 images)..."
(cd "$INSTALL_DIR" && $COMPOSE_CMD up -d 2>&1 | tee -a "$LOGFILE") \
    || print_error "Failed to start Taiga. Check log: $LOGFILE"

# Taiga does NOT auto-create an admin account from 'up -d' alone (unlike
# OpenProject/Nextcloud) — it needs this separate one-off command, per the
# official repo's own README. This runs on EVERY deploy (not just fresh
# ones) and self-detects whether the account already exists, because an
# existing .env/docker-compose.yml only means "reuse config", not "the admin
# account was ever successfully created" — e.g. a deployment made before
# this step existed, or one where a previous attempt failed partway.
[[ -n "${ADMIN_PASSWORD:-}" ]] || ADMIN_PASSWORD=$(generate_secret)

ADMIN_CREATED=false
ADMIN_ALREADY_EXISTED=false
print_info "Checking/creating the admin account (retrying while migrations finish)..."
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
    if (cd "$INSTALL_DIR" && $COMPOSE_CMD -f docker-compose.yml -f docker-compose-inits.yml run --rm \
        -e DJANGO_SUPERUSER_USERNAME=admin \
        -e DJANGO_SUPERUSER_EMAIL=admin@example.com \
        -e DJANGO_SUPERUSER_PASSWORD="$ADMIN_PASSWORD" \
        taiga-manage createsuperuser --noinput >> "$LOGFILE" 2>&1); then
        ADMIN_CREATED=true
        break
    fi
    # createsuperuser --noinput fails the same way whether migrations just
    # haven't finished yet or the account is already there — check the DB
    # directly to tell those apart instead of parsing Django's error text.
    if admin_exists; then
        ADMIN_CREATED=true
        ADMIN_ALREADY_EXISTED=true
        break
    fi
    sleep 5
done

if [[ "$ADMIN_CREATED" == true && "$ADMIN_ALREADY_EXISTED" == false ]]; then
    print_info "Admin account created."
    if [[ "$FRESH_DEPLOY" == false ]]; then
        # Fresh-deploy runs already wrote this to the secrets file earlier;
        # this covers the "existing .env, account created just now" case.
        {
            echo "$(date '+%F %T'): admin account created on an existing deployment"
            echo "  Admin user:     admin"
            echo "  Admin password: $ADMIN_PASSWORD"
        } >> "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
    fi
elif [[ "$ADMIN_CREATED" == true ]]; then
    print_info "Admin account already exists — leaving its password as-is."
else
    print_warn "Could not create/verify the admin account after several attempts — check $LOGFILE, then run manually:"
    print_warn "  cd $INSTALL_DIR && $COMPOSE_CMD -f docker-compose.yml -f docker-compose-inits.yml run --rm taiga-manage createsuperuser"
fi

print_info "Taiga is starting."
echo
echo "──────────────────────────────────────────────"
if [[ -n "$ENV_HOST_PORT" ]]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "${SERVER_IP:-}" ]] && SERVER_IP="<your-server-ip>"
    echo "🌐 URL:          http://$SERVER_IP:$ENV_HOST_PORT"
fi
echo "🔗 Proxy target: taiga-app:80 on 'main-net'"
if [[ "$ADMIN_CREATED" == true && "$ADMIN_ALREADY_EXISTED" == false ]]; then
    echo "👤 First login:  admin / $ADMIN_PASSWORD — also saved to $SECRETS_FILE"
elif [[ "$ADMIN_CREATED" == true ]]; then
    echo "👤 First login:  admin account already set up — see $SECRETS_FILE for its password"
else
    echo "👤 First login:  admin account setup failed — see warning above, and $LOGFILE"
fi
echo "📜 Log:          $LOGFILE"
[[ -f "$SECRETS_FILE" ]] && echo "🔒 Secrets:      $SECRETS_FILE"
echo "──────────────────────────────────────────────"
echo
if [[ -n "$ENV_HOST_PORT" ]]; then
    echo "⚠️  TAIGA_SCHEME/WEBSOCKETS_SCHEME were set to http/ws for this plain-"
    echo "   http:// direct port to work at all. Once you switch to NPM+SSL, edit"
    echo "   TAIGA_DOMAIN to your real domain, TAIGA_SCHEME=https, and"
    echo "   WEBSOCKETS_SCHEME=wss in .env and rerun deploy.sh."
    echo
fi
echo "Set up NGINX Proxy Manager: forward to taiga-app:80, enable Websockets"
echo "Support (needed for the /events real-time path), enable SSL."
echo
echo "To manage: cd $INSTALL_DIR && $COMPOSE_CMD [ps|logs -f|stop|restart]"
