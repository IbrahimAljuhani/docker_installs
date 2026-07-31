#!/bin/bash
# services.sh — lists services and lets you deploy, remove, or reinstall one.
#
# Two modes for finding service files:
#   1) Local checkout: if this file sits inside a real services/ folder with
#      sibling <name>/deploy.sh directories (full repo clone), those are
#      used directly.
#   2) Standalone (curl'd on its own, matching how every other script in this
#      repo is normally fetched — see the root README): no sibling folders
#      exist, so deploying downloads the chosen service's files fresh into
#      ./<name>/ from GitHub.
#
# Usage: bash services.sh
# (not './services.sh' — a fresh git clone/pull doesn't reliably preserve the
# executable bit, and 'bash <file>' works regardless of it)

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "This script must NOT be run as root — each service's own deploy.sh checks that too." >&2
    exit 1
fi

REPO_RAW_BASE="https://raw.githubusercontent.com/IbrahimAljuhani/docker_installs/main/services"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extra files (besides deploy.sh) each service needs — keep this in sync with
# that service's own README.md "Installation" curl commands.
declare -A SERVICE_FILES=(
    [odoo]=""
    [openproject]="docker-compose.yml"
    [nextcloud]="docker-compose.yml"
    [n8n]="docker-compose.yml init-data.sh"
    [taiga]="docker-compose.yml docker-compose-inits.yml taiga-gateway/taiga.conf"
)

print_info() { echo -e "[✓] $1" >&2; }
print_warn() { echo -e "[!] $1" >&2; }

compose_cmd() {
    if docker compose version &>/dev/null; then
        echo "docker compose"
    elif docker-compose version &>/dev/null; then
        echo "docker-compose"
    fi
}

# Prints one instance directory per line for a service's runtime root
# ($HOME/docker/<name>). Single-instance services (openproject, nextcloud,
# n8n) have their compose file directly in that folder; multi-instance ones
# (odoo) have it one level down, in named subfolders — detected generically,
# not hardcoded to odoo specifically.
find_instances() {
    local svc_dir="$1"
    [[ -d "$svc_dir" ]] || return 0
    if [[ -f "$svc_dir/docker-compose.yml" ]]; then
        echo "$svc_dir"
        return 0
    fi
    local d
    for d in "$svc_dir"/*/; do
        [[ -f "${d}docker-compose.yml" ]] && echo "${d%/}"
    done
}

prompt_choice() {
    # $1 = number of items (the menu also gets an implicit "Exit"/"Back" at
    # $1+1). Echoes the chosen index (1-based) via a global, not command
    # substitution (same reasoning as the mem-limit prompts in the service
    # deploy.sh files: keeps the prompt on the real terminal instead of a
    # captured subshell).
    local count="$1" label="${2:-Exit}" exit_num choice
    exit_num=$((count + 1))
    echo "  $exit_num) $label"
    read -rp "Choice (1-$exit_num): " choice || { CHOSEN_INDEX="$exit_num"; return 0; }
    if [[ "$choice" == "$exit_num" ]]; then
        CHOSEN_INDEX="$exit_num"
        return 0
    fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > count )); then
        echo "Invalid choice." >&2
        CHOSEN_INDEX=""
        return 1
    fi
    CHOSEN_INDEX="$choice"
}

# Stops (and optionally wipes) one deployed instance directory.
# Soft removal (default): stops containers, deletes the cached
# docker-compose.yml/override.yml so a future deploy.sh re-copies the latest
# version — .env/secrets/logs are kept so a reinstall can reuse them.
# Full wipe: also removes named volumes and deletes the whole directory.
remove_instance() {
    local instance_dir="$1" cc wipe
    cc="$(compose_cmd)"
    if [[ -z "$cc" ]]; then
        echo "Docker Compose not found." >&2
        return 1
    fi
    read -rp "Also permanently delete this instance's data (database, uploaded files, secrets)? (y/N): " wipe || wipe="n"
    if [[ "${wipe,,}" == "y" ]]; then
        (cd "$instance_dir" && $cc down -v) || true
        rm -rf "$instance_dir"
        print_info "Removed $instance_dir completely (data wiped)."
    else
        (cd "$instance_dir" && $cc down) || true
        rm -f "$instance_dir/docker-compose.yml" "$instance_dir/docker-compose.override.yml"
        print_info "Stopped and removed containers for $instance_dir. Data/.env kept — deploying again will reuse them."
    fi
}

# Deploys $1 — local checkout if available, otherwise downloads it fresh.
# Terminal action: always ends the script (exec).
deploy_service() {
    local name="$1"
    if [[ -f "$SCRIPT_DIR/$name/deploy.sh" ]]; then
        echo "Launching $name..."
        exec bash "$SCRIPT_DIR/$name/deploy.sh"
    fi

    local target_dir="./$name"
    mkdir -p "$target_dir"
    echo "Downloading $name into $target_dir/ ..."
    curl -fsSL -o "$target_dir/deploy.sh" "$REPO_RAW_BASE/$name/deploy.sh"
    local f
    for f in ${SERVICE_FILES[$name]:-}; do
        # mkdir first: some services ship files nested in a subfolder (e.g.
        # taiga/taiga-gateway/taiga.conf) — curl -o doesn't create parents.
        mkdir -p "$(dirname "$target_dir/$f")"
        curl -fsSL -o "$target_dir/$f" "$REPO_RAW_BASE/$name/$f"
    done
    chmod +x "$target_dir/deploy.sh"

    echo "Launching $name..."
    cd "$target_dir"
    exec bash ./deploy.sh
}

# Lets the user pick which instance to act on when a service has more than
# one (odoo). Returns the chosen path in INSTANCE_PATH, or empty if the user
# backs out.
pick_instance() {
    local -a instances=("$@")
    if (( ${#instances[@]} == 1 )); then
        INSTANCE_PATH="${instances[0]}"
        return 0
    fi
    echo "Multiple instances found:"
    local i=1 inst
    for inst in "${instances[@]}"; do
        echo "  $i) $(basename "$inst")"
        i=$((i + 1))
    done
    if ! prompt_choice "${#instances[@]}" "Back"; then
        INSTANCE_PATH=""
        return 1
    fi
    if [[ "$CHOSEN_INDEX" -gt "${#instances[@]}" ]]; then
        INSTANCE_PATH=""
        return 1
    fi
    INSTANCE_PATH="${instances[$((CHOSEN_INDEX - 1))]}"
}

service_menu() {
    # Two separate 'local' statements on purpose: 'local a=1 b=$a' does NOT
    # let the second assignment see the first's new value within the same
    # statement — it evaluates using whatever '$a' was before this line ran
    # (e.g. a stale value from a previous call to this function).
    local name="$1"
    local svc_runtime_dir="$HOME/docker/$name"
    while true; do
        local -a instances=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && instances+=("$line")
        done < <(find_instances "$svc_runtime_dir")

        echo
        if (( ${#instances[@]} > 1 )); then
            echo "'$name' is already deployed (${#instances[@]} instances under $svc_runtime_dir)."
        elif (( ${#instances[@]} == 1 )); then
            echo "'$name' is already deployed under $svc_runtime_dir."
        else
            echo "'$name' is not deployed yet."
        fi
        echo "1) Deploy / manage (runs deploy.sh — safe for new or existing deployments)"
        echo "2) Remove"
        echo "3) Reinstall (remove, then deploy fresh)"
        local choice
        if ! prompt_choice 3 "Back"; then
            continue
        fi
        choice="$CHOSEN_INDEX"
        case "$choice" in
            1) deploy_service "$name" ;;
            2)
                if (( ${#instances[@]} == 0 )); then
                    print_warn "Nothing to remove — '$name' isn't deployed."
                    continue
                fi
                pick_instance "${instances[@]}" || continue
                # '|| true': a failure here (e.g. Docker Compose missing)
                # should return to the menu, not kill the whole session.
                [[ -n "$INSTANCE_PATH" ]] && { remove_instance "$INSTANCE_PATH" || true; }
                ;;
            3)
                if (( ${#instances[@]} > 0 )); then
                    pick_instance "${instances[@]}" || continue
                    [[ -n "$INSTANCE_PATH" ]] && { remove_instance "$INSTANCE_PATH" || true; }
                fi
                print_info "Deploying $name fresh..."
                deploy_service "$name"
                ;;
            4) return ;;
        esac
    done
}

main_menu() {
    # --- Mode 1: local checkout ---
    local -a local_services=()
    local d name
    for d in "$SCRIPT_DIR"/*/; do
        name="$(basename "$d")"
        [[ "$name" == "_template" ]] && continue
        [[ -f "$d/deploy.sh" ]] && local_services+=("$name")
    done

    local -a names=()
    if (( ${#local_services[@]} > 0 )); then
        names=("${local_services[@]}")
    else
        echo "No local service folders found next to this script — service list is the known-services table (deploying downloads from GitHub)."
        names=("${!SERVICE_FILES[@]}")
        IFS=$'\n' names=($(sort <<<"${names[*]}")); unset IFS
    fi

    while true; do
        echo
        echo "Available services:"
        local i=1 s
        for s in "${names[@]}"; do
            echo "  $i) $s"
            i=$((i + 1))
        done
        prompt_choice "${#names[@]}" "Exit" || continue
        (( CHOSEN_INDEX > ${#names[@]} )) && exit 0
        service_menu "${names[$((CHOSEN_INDEX - 1))]}"
    done
}

main_menu
