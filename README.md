# 🐳 Docker & NGINX Proxy Manager Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A smart, interactive Bash script to **automatically install Docker CE, Docker Compose, NGINX Proxy Manager, and Portainer-CE** on multiple Linux distributions — including ARM64 devices like Raspberry Pi.

Perfect for homelab enthusiasts, DevOps beginners, or anyone who wants a quick, secure, and consistent Docker environment with a reverse proxy and management UI.

---

## ✅ Supported Operating Systems

- **Debian** 10 / 11 / 12  
- **Ubuntu** 18.04 / 20.04 / 22.04 / 24.04 (x86_64 & ARM64)  
- **Raspbian** / Raspberry Pi OS (ARM64)  
- **CentOS** 7 / 8 / Stream  
- **Fedora**  
- **Arch Linux**  
- **openSUSE** (Leap & Tumbleweed)

> ✅ The script auto-detects your OS. If detection fails, you can select manually.

---

## 🚀 Features

- **One-command setup** for a full Docker stack.  
- Installs **Docker CE** via the official `get.docker.com` script.  
- Uses the modern **Docker Compose plugin** (`docker compose`, not the legacy binary).  
- Deploys **NGINX Proxy Manager** from a remote `docker-compose.yml` file.  
- Installs **Portainer-CE** for intuitive Docker management.  
- Creates a shared Docker network (`main-net`) for easy container communication.  
- Checks for existing installations to avoid duplicates.  
- Adds your user to the `docker` group (no `sudo` needed after re-login).  
- Clean, color-coded, interactive prompts.  
- Full logging to `~/install_docker_NPM.log`.

---

## 🔗 URLs

- **Script**:  
  [`https://github.com/ibrahimaljuhani/docker_installs/blob/main/install_docker_NPM.sh`](https://github.com/ibrahimaljuhani/docker_installs/blob/main/install_docker_NPM.sh)

- **NGINX Proxy Manager Compose File**:  
  [`https://github.com/ibrahimaljuhani/docker_installs/blob/main/docker_compose_NPM.yml`](https://github.com/ibrahimaljuhani/docker_installs/blob/main/docker_compose_NPM.yml)

---

## 📥 Installation & Usage

### 1. Download the script
```bash
curl -fsSL -o install_docker_NPM.sh https://raw.githubusercontent.com/ibrahimaljuhani/docker_installs/main/install_docker_NPM.sh
```

### 2. Make it executable
```bash
chmod +x install_docker_NPM.sh
```

### 3. Run it
```bash
./install_docker_NPM.sh
```

💡 You’ll be guided through an interactive menu to choose what to install.

---

## 🔐 Default Credentials

### NGINX Proxy Manager
- **URL**: `http://YOUR_SERVER_IP:81`  
- **Email**: `admin@example.com`  
- **Password**: `changeme`  
  ⚠️ **Change this immediately after first login!**

### Portainer-CE
- **URL**: `http://YOUR_SERVER_IP:9000`  
- **First login**: Create your own admin account.

---

## 📁 Directory Structure After Install

All apps are installed under your home directory:

```bash
~/docker/
└── npm/               # NGINX Proxy Manager
```

> Portainer-CE stores data in a Docker volume named `portainer_data`.

---

## 🛡️ Security Notes

- The script adds your user to the `docker` group. **Log out and back in** for this to take effect.  
- Never expose NGINX Proxy Manager or Portainer to the public internet without authentication or a firewall.  
- Always change default passwords on first use.  
- 🔁 **After installation**, log out and log back in (or reboot) to apply Docker group permissions.

---

## ⚙️ System Requirements (Optional)

- Minimum **1 GB RAM** (2 GB recommended)  
- At least **10 GB free disk space**  
- Internet connection required during setup

---

## 🧩 Troubleshooting

- **Docker not found after installation:**  
  → Log out and log back in (or reboot) to refresh group permissions.  

- **Portainer or NPM container not running:**  
  → Check logs using `docker ps -a` or `docker logs <container_name>`.

---

## 📜 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

## 🙌 Author

**Ibrahim Aljuhani**  
GitHub: [@ibrahimaljuhani](https://github.com/ibrahimaljuhani)
