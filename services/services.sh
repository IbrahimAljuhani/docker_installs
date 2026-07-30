#!/bin/bash
# services.sh — lists services and launches the one you pick.
#
# Two modes:
#   1) Local checkout: if this file sits inside a real services/ folder with
#      sibling <name>/deploy.sh directories (full repo clone), those are
#      used directly.
#   2) Standalone (curl'd on its own, matching how every other script in this
#      repo is normally fetched — see the root README): no sibling folders
#      exist, so this downloads the chosen service's files fresh into
#      ./<name>/ from GitHub and runs it from there.
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
)

prompt_choice() {
    # $1 = number of items (the menu also gets an implicit "Exit" at $1+1).
    # Echoes the chosen index (1-based) via a global, not command substitution
    # (same reasoning as the mem-limit prompts in the service deploy.sh files:
    # keeps the prompt on the real terminal instead of a captured subshell).
    local count="$1" exit_num choice
    exit_num=$((count + 1))
    echo "  $exit_num) Exit"
    read -rp "Choice (1-$exit_num): " choice || exit 0
    if [[ "$choice" == "$exit_num" ]]; then
        exit 0
    fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > count )); then
        echo "Invalid choice." >&2
        exit 1
    fi
    CHOSEN_INDEX="$choice"
}

# --- Mode 1: local checkout ---
local_services=()
for d in "$SCRIPT_DIR"/*/; do
    name="$(basename "$d")"
    [[ "$name" == "_template" ]] && continue
    [[ -f "$d/deploy.sh" ]] && local_services+=("$name")
done

if (( ${#local_services[@]} > 0 )); then
    echo "Available services (local checkout):"
    i=1
    for s in "${local_services[@]}"; do
        echo "  $i) $s"
        i=$((i + 1))
    done
    CHOSEN_INDEX=""
    prompt_choice "${#local_services[@]}"
    chosen="${local_services[$((CHOSEN_INDEX - 1))]}"
    echo "Launching $chosen..."
    # 'bash <file>' instead of exec'ing it directly: a fresh git clone
    # doesn't guarantee the executable bit survived, and this works either way.
    exec bash "$SCRIPT_DIR/$chosen/deploy.sh"
fi

# --- Mode 2: standalone — no sibling service folders next to this script ---
echo "No local service folders found next to this script — fetching services from GitHub."
names=("${!SERVICE_FILES[@]}")
IFS=$'\n' names=($(sort <<<"${names[*]}")); unset IFS

echo "Available services:"
i=1
for s in "${names[@]}"; do
    echo "  $i) $s"
    i=$((i + 1))
done
CHOSEN_INDEX=""
prompt_choice "${#names[@]}"
chosen="${names[$((CHOSEN_INDEX - 1))]}"

target_dir="./$chosen"
mkdir -p "$target_dir"
echo "Downloading $chosen into $target_dir/ ..."
curl -fsSL -o "$target_dir/deploy.sh" "$REPO_RAW_BASE/$chosen/deploy.sh"
for f in ${SERVICE_FILES[$chosen]}; do
    curl -fsSL -o "$target_dir/$f" "$REPO_RAW_BASE/$chosen/$f"
done
chmod +x "$target_dir/deploy.sh"

echo "Launching $chosen..."
cd "$target_dir"
exec bash ./deploy.sh
