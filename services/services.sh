#!/bin/bash
# services.sh — lists services under this folder and launches the one you pick.
# Run this after install_docker_core.sh (or let it invoke this automatically
# via its "Install a service" menu option, if you have the full repo checked
# out next to it).
#
# Usage: ./services.sh

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "This script must NOT be run as root — each service's own deploy.sh checks that too." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

services=()
for d in "$SCRIPT_DIR"/*/; do
    name="$(basename "$d")"
    [[ "$name" == "_template" ]] && continue
    [[ -f "$d/deploy.sh" ]] && services+=("$name")
done

if (( ${#services[@]} == 0 )); then
    echo "No services with a deploy.sh found under $SCRIPT_DIR" >&2
    exit 1
fi

echo "Available services:"
i=1
for s in "${services[@]}"; do
    echo "  $i) $s"
    i=$((i + 1))
done
echo "  $i) Exit"

read -rp "Choice (1-$i): " choice || exit 0

if [[ "$choice" == "$i" ]]; then
    exit 0
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#services[@]} )); then
    echo "Invalid choice." >&2
    exit 1
fi

chosen="${services[$((choice - 1))]}"
echo "Launching $chosen..."
exec "$SCRIPT_DIR/$chosen/deploy.sh"
