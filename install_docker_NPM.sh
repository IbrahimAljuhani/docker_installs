#!/bin/bash

# install_docker_NPM.sh
# Author: Ibrahim Aljuhani
# GitHub: https://github.com/ibrahimaljuhani/docker_installs
# Purpose: Install Docker CE, Docker Compose, NGINX Proxy Manager, and Portainer-CE

set -euo pipefail

LOGFILE="$HOME/install_docker_NPM.log"
NPM_COMPOSE_URL="https://raw.githubusercontent.com/ibrahimaljuhani/docker_installs/main/docker_compose_NPM.yml"

# Color codes
INFO='\033[0;36m'
OK='\033[0;32m'
WARN='\033[0;33m'
ERROR='\033[0;31m'
NC='\033[0m' # No Color

print_info()    { echo -e "${INFO}[INFO]${NC} $1"; }
print_ok()      { echo -e "${OK}[OK]${NC} $1"; }
print_warn()    { echo -e "${WARN}[WARN]${NC} $1"; }
print_error()   { echo -e "${ERROR}[ERROR]${NC} $1"; }

# Spinner for background tasks
spinner() {
    local pid=$1
    local delay=0.2
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf " \b\b\b\b\b\b"
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu)
                if [[ "$(uname -m)" == "aarch64" ]]; then
                    echo "ubuntu-arm64"
                else
                    echo "ubuntu"
                fi
                ;;
            debian)
                if [[ "$(uname -m)" == "aarch64" ]]; then
                    echo "raspbian"
                else
                    echo "debian"
                fi
                ;;
            centos|fedora|rhel) echo "centos" ;;
            arch) echo "arch" ;;
            opensuse-leap|opensuse-tumbleweed) echo "opensuse" ;;
            raspbian) echo "raspbian" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

# Map detected OS to internal ID
map_os() {
    case "$1" in
        debian|ubuntu) echo "debian" ;;
        ubuntu-arm64) echo "ubuntu-arm64" ;;
        raspbian) echo "raspbian" ;;
        centos) echo "centos" ;;
        arch) echo "arch" ;;
        opensuse) echo "opensuse" ;;
        *) echo "unknown" ;;
    esac
}

DETECTED=$(detect_os)
OS=$(map_os "$DETECTED")

print_info "Detected OS: $DETECTED"

if [[ "$OS" == "unknown" ]]; then
    print_warn "Could not auto-detect your OS. Please choose manually."
    PS3="Select your OS: "
    options=(
        "Debian / Ubuntu (x86_64)"
        "Ubuntu (ARM64)"
        "Raspbian (ARM64)"
        "CentOS / Fedora"
        "Arch Linux"
        "openSUSE"
        "Cancel"
    )
    select opt in "${options[@]}"; do
        case $REPLY in
            1) OS="debian"; break ;;
            2) OS="ubuntu-arm64"; break ;;
            3) OS="raspbian"; break ;;
            4) OS="centos"; break ;;
            5) OS="arch"; break ;;
            6) OS="opensuse"; break ;;
            7) exit 0 ;;
            *) print_error "Invalid selection." ;;
        esac
    done
fi

# Check existing installations
DOCKER_INSTALLED=false
DOCKER_ACTIVE=false
COMPOSE_INSTALLED=false

if command -v docker &>/dev/null; then
    DOCKER_INSTALLED=true
    if sudo systemctl is-active --quiet docker; then
        DOCKER_ACTIVE=true
    fi
fi

if docker compose version &>/dev/null; then
    COMPOSE_INSTALLED=true
fi

# User choices
echo
if [[ "$DOCKER_ACTIVE" == true ]]; then
    print_ok "Docker is already installed and running."
    INSTALL_DOCKER="n"
else
    read -rp "$(print_info 'Install Docker-CE? (y/n): ')" INSTALL_DOCKER
fi

if [[ "$COMPOSE_INSTALLED" == true ]]; then
    print_ok "Docker Compose (plugin) is already installed."
    INSTALL_COMPOSE="n"
else
    read -rp "$(print_info 'Install Docker Compose? (y/n): ')" INSTALL_COMPOSE
fi

read -rp "$(print_info 'Install NGINX Proxy Manager? (y/n): ')" INSTALL_NPM
read -rp "$(print_info 'Install Portainer-CE? (y/n): ')" INSTALL_PORTAINER

# Install system dependencies
install_deps() {
    case "$OS" in
        debian|ubuntu-arm64|raspbian)
            sudo apt update >> "$LOGFILE" 2>&1
            sudo apt install -y curl wget git >> "$LOGFILE" 2>&1
            ;;
        centos)
            sudo dnf install -y curl wget git >> "$LOGFILE" 2>&1
            ;;
        arch)
            sudo pacman -Sy --noconfirm curl wget git >> "$LOGFILE" 2>&1
            ;;
        opensuse)
            sudo zypper refresh >> "$LOGFILE" 2>&1
            sudo zypper install -y curl wget git >> "$LOGFILE" 2>&1
            ;;
    esac
}

# Install Docker
install_docker() {
    print_info "Installing Docker-CE..."
    curl -fsSL https://get.docker.com | sh >> "$LOGFILE" 2>&1 &
    spinner $!
    sudo systemctl enable --now docker >> "$LOGFILE" 2>&1
    sudo usermod -aG docker "$USER" >> "$LOGFILE" 2>&1
    print_ok "Docker installed. Log out and back in for group changes to apply."
}

# Install Docker Compose plugin
install_compose() {
    print_info "Installing Docker Compose plugin..."
    case "$OS" in
        arch)
            sudo pacman -S --noconfirm docker-compose >> "$LOGFILE" 2>&1
            ;;
        centos)
            sudo dnf install -y docker-compose-plugin >> "$LOGFILE" 2>&1
            ;;
        opensuse)
            sudo zypper install -y docker-compose-plugin >> "$LOGFILE" 2>&1
            ;;
        *)
            # get.docker.com usually installs compose plugin on Debian/Ubuntu
            # Ensure it's available
            if ! docker compose version &>/dev/null; then
                sudo apt install -y docker-compose-plugin >> "$LOGFILE" 2>&1
            fi
            ;;
    esac
    print_ok "Docker Compose is ready."
}

# Main execution block
{
    install_deps

    if [[ "${INSTALL_DOCKER,,}" == "y" ]]; then
        install_docker
    fi

    if [[ "${INSTALL_COMPOSE,,}" == "y" ]]; then
        install_compose
    fi

    # Ensure Docker is running
    if ! sudo systemctl is-active --quiet docker; then
        print_error "Docker service failed to start. Check $LOGFILE."
        exit 1
    fi

    # Create shared Docker network
    if ! docker network ls | grep -q "main-net"; then
        docker network create main-net >> "$LOGFILE" 2>&1
    fi

    # Install NGINX Proxy Manager
    if [[ "${INSTALL_NPM,,}" == "y" ]]; then
        print_info "Installing NGINX Proxy Manager..."
        mkdir -p "$HOME/docker/npm"
        cd "$HOME/docker/npm"
        curl -s "$NPM_COMPOSE_URL" -o docker-compose.yml
        docker compose up -d >> "$LOGFILE" 2>&1
        print_ok "NGINX Proxy Manager installed."
    fi

    # Install Portainer-CE
    if [[ "${INSTALL_PORTAINER,,}" == "y" ]]; then
        print_info "Installing Portainer-CE..."
        docker volume create portainer_data >> "$LOGFILE" 2>&1
        docker run -d \
            -p 8000:8000 -p 9000:9000 \
            --name=portainer \
            --restart=always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data \
            --network main-net \
            portainer/portainer-ce:latest >> "$LOGFILE" 2>&1
        print_ok "Portainer-CE installed."
    fi

    # Final summary
    echo
    print_ok "Installation completed successfully!"
    echo

    SERVER_IP=$(hostname -I | awk '{print $1}')

    if [[ "${INSTALL_NPM,,}" == "y" ]]; then
        echo "→ NGINX Proxy Manager:"
        echo "   URL:      http://$SERVER_IP:81"
        echo "   Username: admin@example.com"
        echo "   Password: changeme"
        echo
    fi

    if [[ "${INSTALL_PORTAINER,,}" == "y" ]]; then
        echo "→ Portainer-CE:"
        echo "   URL: http://$SERVER_IP:9000"
        echo "   (Create admin account on first login)"
        echo
    fi

    echo "Log file: $LOGFILE"
    echo "Note: If you added your user to the 'docker' group, log out and back in to use Docker without sudo."

} 2>> "$LOGFILE"

exit 0