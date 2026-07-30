#!/bin/bash
# deploy.sh (services/odoo)
# Author: Ibrahim Aljuhani (Fixed Version - Official Images)
# Purpose: Install Odoo in Docker using OFFICIAL Docker Hub images
# Fixed: 2026-07-11
#
# CHANGELOG vs original:
#   1. POSTGRES_DB is now "postgres" (not the instance DB name) so Odoo
#      creates & initializes the actual database itself via
#      /web/database/manager instead of finding an empty, uninitialized
#      DB and throwing "ir_module_module does not exist".
#   2. /var/lib/odoo is now a named Docker volume instead of a bind mount,
#      so Docker preserves the correct ownership from the image instead of
#      inheriting the host user's UID/GID (fixes "Permission denied:
#      /var/lib/odoo/sessions").
#   3. ./config and ./addons (which must stay as bind mounts, since users
#      edit them from the host) are chown'ed to the odoo container's real
#      UID/GID, detected dynamically instead of hardcoded 100:101.
#   4. Healthcheck no longer assumes curl exists inside the image; uses
#      python3 (bundled with Odoo) instead.
#   5. postgres:15 -> postgres:17.
#   6. DB_USER / DB_NAME are now validated like the instance name.
#   7. mem_limit/mem_reservation added alongside "deploy:" so memory
#      limits also apply under plain `docker-compose` (non-swarm), where
#      "deploy:" is silently ignored.
#   8. chown warning for config/addons now tries direct chown, then
#      passwordless sudo, then explains it's usually harmless instead of
#      sounding like a blocking error.
#   9. New option 4 in the version menu: use a custom image (your own
#      build, Docker Hub, or private registry), validated for format and
#      existence (locally or via `docker manifest inspect`) before use.
#  10. WebSocket/longpolling (port 8072) is now exposed and enabled.
#      Odoo's gevent worker only starts when "workers" >= 1, so the
#      config now sets workers=2 / max_cron_threads=1 / gevent_port=8072
#      — without this, live chat, POS sync, and bus notifications
#      silently fall back to polling or don't work at all.
#  11. FIX: config/odoo.conf permissions. An earlier revision set this to
#      chmod 600, which broke the container (it's owned by the host user,
#      not the container's odoo uid, so the odoo process couldn't read
#      its own config -> crash loop). Now it's chowned to the odoo
#      user/group first, then locked to 640 (falls back to 644, with a
#      warning, if chown isn't possible without sudo).

set -euo pipefail

# Handle --help/-h before anything else (including the root check below) so
# it works no matter who invokes the script.
if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Install Odoo in Docker using official images."
            exit 0
            ;;
    esac
fi

INSTALL_DIR="$HOME/docker/odoo"
LOGFILE="$INSTALL_DIR/deploy.log"
SECRETS_FILE="$INSTALL_DIR/.odoo-docker-secrets.txt"

# -----------------------------
# 🎨 Terminal Colors
# -----------------------------
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# -----------------------------
# 🧾 Utility Functions
# -----------------------------
print_info()  { echo -e "${GREEN}[✓]${RESET} $1" >&2; }
print_warn()  { echo -e "${YELLOW}[!]${RESET} $1" >&2; }
print_error() { echo -e "${RED}[✗]${RESET} $1" >&2; exit 1; }
print_step()  { echo -e "\n${BLUE}${BOLD}==> $1${RESET}" >&2; }

# -----------------------------
# 🚫 Prevent root execution
# -----------------------------
if [[ $EUID -eq 0 ]]; then
  print_error "This script must NOT be run as root. Please run as a regular user in the docker group."
fi

# -----------------------------
# 🔧 Check prerequisites
# -----------------------------
check_prerequisites() {
    local missing=()

    if ! command -v docker &>/dev/null; then
        missing+=("Docker CE")
    fi

    # detect docker compose command
    if docker compose version &>/dev/null; then
        COMPOSE_CMD="docker compose"
    elif docker-compose version &>/dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        missing+=("Docker Compose")
    fi

    if ! command -v openssl &>/dev/null; then
        missing+=("openssl")
    fi
    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required components: ${missing[*]}. Please install them first."
    fi

    print_info "All required components are installed."
}

# -----------------------------
# 📦 Validate identifiers (instance name / db user / db name)
# -----------------------------
validate_identifier() {
    local value="$1" label="$2"
    if [[ ! "$value" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        print_error "Invalid $label. Must start with a lowercase letter and contain only letters, digits, hyphens, or underscores."
    fi
}

# -----------------------------
# 🏷️ Choose Odoo version
# -----------------------------
choose_odoo_version() {
    echo -e "${BOLD}Choose Odoo version:${RESET}" >&2
    echo "1) 19.0 (Development - Use at your own risk)"
    echo "2) 18.0 (Stable - Recommended)"
    echo "3) 17.0 (LTS)"
    echo "4) Custom image (your own Odoo image, e.g. myrepo/odoo:custom)"
    local choice
    while true; do
        read -rp "Enter choice (1-4): " choice
        case "$choice" in
            1)
                ODOO_VERSION="19.0"
                print_warn "⚠️  Odoo 19.0 is still in development. May not have official Docker image yet."
                break
                ;;
            2) ODOO_VERSION="18.0"; break ;;
            3) ODOO_VERSION="17.0"; break ;;
            4) choose_custom_image; break ;;
            *) echo "Invalid choice. Try again." ;;
        esac
    done
}

# -----------------------------
# 🖼️  Choose a custom Odoo image (own build / Docker Hub / private registry)
# -----------------------------
choose_custom_image() {
    local image confirm
    while true; do
        read -rp "Enter full image name (e.g. myrepo/odoo:18-custom): " image

        if [[ -z "$image" ]]; then
            echo "Image name cannot be empty."
            continue
        fi
        # repo[/repo...][:tag] — require an explicit tag (avoid implicit 'latest')
        if [[ ! "$image" =~ ^[a-z0-9.-]+(:[0-9]+)?(/[a-z0-9._-]+)*:[a-zA-Z0-9._-]+$ ]]; then
            echo "Invalid format, or missing tag. Expected something like: repo/image:tag"
            continue
        fi

        print_info "Checking if '$image' exists locally or on the registry..."
        if docker image inspect "$image" &>/dev/null; then
            print_info "Found locally."
        elif docker manifest inspect "$image" &>/dev/null; then
            print_info "Found on the registry."
        else
            print_warn "Could not verify '$image' — it may not exist, or it's in a private registry that needs 'docker login' first."
            read -rp "Continue anyway? (y/N): " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || continue
        fi
        break
    done
    CUSTOM_IMAGE_OVERRIDE="$image"
    ODOO_VERSION="custom"
}

# -----------------------------
# 📁 Prepare install directory
# -----------------------------
prepare_install_dir() {
    mkdir -p "$INSTALL_DIR" || print_error "Failed to create $INSTALL_DIR"
    [[ -w "$INSTALL_DIR" ]] || print_error "No write permission for $INSTALL_DIR"
}

# -----------------------------
# 🔑 Generate random password
# -----------------------------
generate_password() {
    local _raw
    _raw=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9')
    echo "${_raw:0:20}"
}

# -----------------------------
# ⚓ Check port availability
# -----------------------------
check_port() {
    local port="$1"
    local in_use=false
    if command -v ss &>/dev/null; then
        ss -tuln | grep -q ":$port\b" && in_use=true
    elif command -v netstat &>/dev/null; then
        netstat -tuln | grep -q ":$port\b" && in_use=true
    else
        print_warn "Cannot verify port availability (ss/netstat not found)."
        return 0
    fi

    if [[ "$in_use" == true ]]; then
        print_warn "Port $port is already in use."
        read -rp "Continue anyway? (y/N): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || print_error "Aborted due to port conflict on $port."
    fi
}

# -----------------------------
# 🆔 Detect the real UID/GID of the "odoo" user inside the image
#     (avoids hardcoding 100:101, which can differ between image builds
#     and may collide with reserved system UIDs like _apt/systemd-journal)
# -----------------------------
detect_odoo_ids() {
    local image="$1"
    print_info "Detecting odoo user UID/GID inside $image (pulling image if needed)..."
    local id_output
    id_output=$(docker run --rm --entrypoint id "$image" odoo 2>/dev/null || true)

    if [[ -n "$id_output" ]]; then
        ODOO_UID=$(echo "$id_output" | grep -oP 'uid=\K[0-9]+' || true)
        ODOO_GID=$(echo "$id_output" | grep -oP 'gid=\K[0-9]+' || true)
    fi

    if [[ -z "${ODOO_UID:-}" || -z "${ODOO_GID:-}" ]]; then
        print_warn "Could not detect odoo UID/GID automatically, falling back to 100:101."
        ODOO_UID=100
        ODOO_GID=101
    else
        print_info "Detected odoo user as UID=$ODOO_UID GID=$ODOO_GID"
    fi
}

# -----------------------------
# 🚀 Main installation process
# -----------------------------
main() {
    print_step "Checking prerequisites..."
    check_prerequisites

    prepare_install_dir

    read -rp "Enter instance name (e.g., odoo-prod): " INSTANCE_NAME
    validate_identifier "$INSTANCE_NAME" "instance name"
    INSTANCE_DIR="$INSTALL_DIR/$INSTANCE_NAME"
    [[ -d "$INSTANCE_DIR" ]] && print_error "Instance '$INSTANCE_NAME' already exists."

    choose_odoo_version
    if [[ "$ODOO_VERSION" == "custom" ]]; then
        CUSTOM_IMAGE="$CUSTOM_IMAGE_OVERRIDE"
    else
        CUSTOM_IMAGE="odoo:$ODOO_VERSION"
    fi

    read -rp "Enter HTTP port (default 8069): " ODOO_PORT
    ODOO_PORT="${ODOO_PORT:-8069}"
    if ! [[ "$ODOO_PORT" =~ ^[0-9]+$ ]] || [ "$ODOO_PORT" -lt 1024 ] || [ "$ODOO_PORT" -gt 65535 ]; then
        print_error "Port must be between 1024 and 65535."
    fi
    check_port "$ODOO_PORT"

    LONGPOLLING_DEFAULT=$((ODOO_PORT + 3))
    read -rp "Enter WebSocket/longpolling port (default $LONGPOLLING_DEFAULT): " LONGPOLLING_PORT
    LONGPOLLING_PORT="${LONGPOLLING_PORT:-$LONGPOLLING_DEFAULT}"
    if ! [[ "$LONGPOLLING_PORT" =~ ^[0-9]+$ ]] || [ "$LONGPOLLING_PORT" -lt 1024 ] || [ "$LONGPOLLING_PORT" -gt 65535 ]; then
        print_error "Port must be between 1024 and 65535."
    fi
    if [ "$LONGPOLLING_PORT" -eq "$ODOO_PORT" ]; then
        print_error "WebSocket/longpolling port must be different from the HTTP port."
    fi
    check_port "$LONGPOLLING_PORT"

    echo
    echo "Database Configuration:"
    read -rp "Enter PostgreSQL username (default: odoo): " DB_USER
    DB_USER="${DB_USER:-odoo}"
    validate_identifier "$DB_USER" "database username"

    read -rsp "Enter PostgreSQL password (leave blank to auto-generate): " DB_PASS
    echo
    if [ -z "$DB_PASS" ]; then
        DB_PASS=$(generate_password)
        print_warn "Auto-generated DB password: $DB_PASS"
    fi

    read -rp "Enter Database name (default: odoo) — this is just the name you'll type in Odoo's database manager on first login, it is NOT pre-created: " DB_NAME
    DB_NAME="${DB_NAME:-odoo}"
    validate_identifier "$DB_NAME" "database name"

    # Detect the odoo container's UID/GID so bind-mounted config/addons
    # folders are owned correctly. This also pre-pulls the image.
    detect_odoo_ids "$CUSTOM_IMAGE"

    # Shared reverse-proxy network (created by install_docker_core.sh). Created
    # here too, idempotently, so this script also works standalone/out of order.
    if ! docker network ls --format '{{.Name}}' | grep -qx "main-net"; then
        # '|| true': install_docker_core.sh (or another service) may win a
        # create race between the check above and this line — that's harmless,
        # but re-verify below so a genuine failure isn't reported as OK.
        docker network create main-net || true
        if docker network ls --format '{{.Name}}' | grep -qx "main-net"; then
            print_info "Created docker network 'main-net'."
        else
            print_error "Failed to create docker network 'main-net'."
        fi
    fi

    mkdir -p "$INSTANCE_DIR"/{config,addons,db-data}

    # Give the odoo container user write access to the bind-mounted folders
    # Try direct chown first (works if you already own the files), then fall
    # back to non-interactive sudo (only succeeds if you have passwordless
    # sudo cached — this never blocks the script waiting for a password).
    if chown -R "$ODOO_UID:$ODOO_GID" "$INSTANCE_DIR/config" "$INSTANCE_DIR/addons" 2>/dev/null; then
        print_info "Set ownership of config/addons to $ODOO_UID:$ODOO_GID."
    elif sudo -n chown -R "$ODOO_UID:$ODOO_GID" "$INSTANCE_DIR/config" "$INSTANCE_DIR/addons" 2>/dev/null; then
        print_info "Set ownership of config/addons to $ODOO_UID:$ODOO_GID (via sudo)."
    else
        print_warn "Could not chown config/addons automatically. This is usually harmless — Odoo only reads from these two folders in normal operation and doesn't need write access to them. You'd only need this if you plan to let Odoo itself write into config/addons (uncommon). If you hit permission errors later, run:"
        print_warn "  sudo chown -R $ODOO_UID:$ODOO_GID $INSTANCE_DIR/{config,addons}"
    fi

    ADMIN_PASS=$(generate_password)

    # Save secrets securely
    if [[ ! -f "$SECRETS_FILE" ]]; then
        echo "# Auto-generated Odoo secrets - DO NOT SHARE" > "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
    fi
    {
        echo "$(date '+%F %T'): Instance '$INSTANCE_NAME' admin password: $ADMIN_PASS"
        echo "$(date '+%F %T'): DB '$DB_NAME' credentials: $DB_USER / $DB_PASS"
    } >> "$SECRETS_FILE"
    print_info "Credentials saved to $SECRETS_FILE."
    print_warn "⚠️  Keep this file secure. Never share it!"

    # Create .env file for docker-compose
    # NOTE: POSTGRES_DB is intentionally "postgres" (the default maintenance
    # DB), NOT $DB_NAME. Odoo creates/initializes the real database itself
    # the first time you visit /web/database/manager. Pre-creating an empty
    # DB_NAME database here would make Odoo think it's already initialized
    # and fail with "ir_module_module does not exist".
    cat >"$INSTANCE_DIR/.env" <<EOF
POSTGRES_DB=postgres
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$DB_PASS
ADMIN_PASS=$ADMIN_PASS
EOF
    chmod 600 "$INSTANCE_DIR/.env"

    # -----------------------------
    # 🧱 Generate docker-compose.yml
    # -----------------------------
    cat >"$INSTANCE_DIR/docker-compose.yml" <<EOF
services:
  odoo:
    image: $CUSTOM_IMAGE
    container_name: odoo-$INSTANCE_NAME
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "$ODOO_PORT:8069"
      - "$LONGPOLLING_PORT:8072"
    volumes:
      - ./config:/etc/odoo
      - ./addons:/mnt/extra-addons
      - odoo-data:/var/lib/odoo
    restart: unless-stopped
    env_file:
      - .env
    networks:
      - odoo-net-$INSTANCE_NAME
      - main-net
    mem_limit: 2g
    mem_reservation: 512m
    healthcheck:
      test: ["CMD", "python3", "-c", "import urllib.request as u,sys; sys.exit(0 if u.urlopen('http://localhost:8069/web/health').status==200 else 1)"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 2g
        reservations:
          memory: 512m

  db:
    image: postgres:17
    container_name: odoo-$INSTANCE_NAME-db
    env_file:
      - .env
    volumes:
      - ./db-data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \$POSTGRES_USER -d postgres"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - odoo-net-$INSTANCE_NAME
    mem_limit: 1g
    mem_reservation: 256m
    deploy:
      resources:
        limits:
          memory: 1g
        reservations:
          memory: 256m

volumes:
  odoo-data:

networks:
  odoo-net-$INSTANCE_NAME:
    driver: bridge
  main-net:
    external: true
EOF

    # Odoo config — explicit DB connection settings avoid reliance on entrypoint defaults.
    # db_name is intentionally left unset so Odoo shows the database
    # selector/manager on first visit instead of assuming a DB already exists.
    cat >"$INSTANCE_DIR/config/odoo.conf" <<EOF
[options]
admin_passwd = ${ADMIN_PASS}
addons_path   = /mnt/extra-addons
data_dir      = /var/lib/odoo
db_host       = db
db_port       = 5432
db_user       = ${DB_USER}
db_password   = ${DB_PASS}
list_db       = True
workers       = 2
max_cron_threads = 1
gevent_port   = 8072
EOF
    # odoo.conf is bind-mounted and read directly by the odoo user (uid
    # $ODOO_UID) inside the container. It must stay readable by that user.
    # chmod 600 alone would lock the container OUT of its own config file
    # (since the file is owned by the host user, not uid $ODOO_UID) and
    # cause a permission-denied crash loop. So: try to hand ownership to
    # the container's odoo user first, then lock it down to 640 (owner +
    # group read/write only). If we can't chown (no sudo), fall back to
    # 644 so the container can still read it — world-readable beats
    # "secure but broken" on a single-user dev/test box.
    if chown "$ODOO_UID:$ODOO_GID" "$INSTANCE_DIR/config/odoo.conf" 2>/dev/null; then
        chmod 640 "$INSTANCE_DIR/config/odoo.conf"
    elif sudo -n chown "$ODOO_UID:$ODOO_GID" "$INSTANCE_DIR/config/odoo.conf" 2>/dev/null; then
        # We just handed ownership to $ODOO_UID via sudo, so a plain
        # (non-sudo) chmod would now fail with "Operation not permitted"
        # -- only the file's owner (or root) may change its mode. Use
        # sudo here too, consistently.
        sudo -n chmod 640 "$INSTANCE_DIR/config/odoo.conf" 2>/dev/null \
            || print_warn "chown via sudo succeeded but chmod did not; file may be left at default permissions."
    else
        chmod 644 "$INSTANCE_DIR/config/odoo.conf"
        print_warn "Could not chown odoo.conf to the container's odoo user; left it world-readable (644) so the container can still read it. Run 'sudo chown $ODOO_UID:$ODOO_GID $INSTANCE_DIR/config/odoo.conf && sudo chmod 640 $INSTANCE_DIR/config/odoo.conf' to tighten this."
    fi

    print_step "Starting Odoo instance..."
    (cd "$INSTANCE_DIR" && $COMPOSE_CMD up -d 2>&1 | tee -a "$LOGFILE") \
        || print_error "Failed to start Odoo containers. Check log: $LOGFILE"
    print_info "Containers started successfully."

    # Detect server IP (more compatible)
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip addr show scope global | grep inet | grep -v docker | awk '{print $2}' | cut -d'/' -f1 | head -n1)
    [[ -z "$SERVER_IP" ]] && SERVER_IP="127.0.0.1"

    if [[ "$SERVER_IP" == "127.0.0.1" ]]; then
        print_warn "Could not detect public IP. Use localhost or configure network."
    fi

    print_info "Odoo instance '$INSTANCE_NAME' is running!"
    echo
    echo "──────────────────────────────────────────────"
    echo "🌐 URL:          http://$SERVER_IP:$ODOO_PORT"
    echo "🔌 WebSocket:    http://$SERVER_IP:$LONGPOLLING_PORT  (live chat / POS / bus notifications)"
    echo "🔗 Proxy target: odoo-$INSTANCE_NAME:8069 (and :8072 for WS) on the 'main-net' network — use this in NGINX Proxy Manager instead of a host port"
    echo "📦 Odoo Version: $ODOO_VERSION"
    echo "🖼️  Image:        $CUSTOM_IMAGE"
    echo "🗄️  Database:     $DB_NAME  (not yet created — see next step below)"
    echo "👤 DB User:      $DB_USER"
    echo "🔑 DB Password:  $DB_PASS"
    echo "🔐 Admin Pass:   $ADMIN_PASS"
    echo "⚙️  Config:       $INSTANCE_DIR/config/odoo.conf"
    echo "🧩 Addons:       $INSTANCE_DIR/addons"
    echo "💾 DB Data:      $INSTANCE_DIR/db-data"
    echo "📁 Data Volume:  odoo-data (named Docker volume, not a host folder)"
    echo "📜 Log:          $LOGFILE"
    echo "🔒 Secrets:      $SECRETS_FILE"
    echo "──────────────────────────────────────────────"
    echo
    echo "👉 NEXT STEP (first run only):"
    echo "   Open http://$SERVER_IP:$ODOO_PORT/web/database/manager"
    echo "   and click 'Create Database' using:"
    echo "     - Master Password: $ADMIN_PASS"
    echo "     - Database Name:   $DB_NAME"
    echo "   Odoo will create and initialize the DB tables itself."
    echo
    echo "To manage containers:"
    echo "  cd $INSTANCE_DIR && $COMPOSE_CMD [ps|logs|stop|rm]"
    echo
    echo "💡 Tip: Add your custom addons to $INSTANCE_DIR/addons"
    echo
    echo "┌─────────────────────────────────────────────┐"
    echo "│  🔒  SECURITY REMINDER — ACTION REQUIRED    │"
    echo "├─────────────────────────────────────────────┤"
    echo "│  Passwords above are shown in plain text.   │"
    echo "│  Before leaving this terminal:              │"
    echo "│    1. Save credentials from: $SECRETS_FILE"
    echo "│    2. Clear terminal history:               │"
    echo "│         history -c && history -w            │"
    echo "└─────────────────────────────────────────────┘"
}

main "$@"
