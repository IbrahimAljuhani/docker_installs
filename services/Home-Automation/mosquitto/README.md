# 🦟 Eclipse Mosquitto

Deploys [Eclipse Mosquitto](https://mosquitto.org/) — the reference MQTT broker — using the [`eclipse-mosquitto` Docker Official Image](https://hub.docker.com/_/eclipse-mosquitto).

**One container, a few megabytes of RAM.** This is the smallest service in the repo.

MQTT is the message bus most home-automation and IoT devices speak: sensors and switches publish to topics, and [Home Assistant](../home-assistant/) subscribes to them. Mosquitto is the broker in the middle.

---

## ⚠️ Two things about Mosquitto that catch everyone

**1. Version 2.x refuses remote connections unless you write a config file.**

Run the image with no configuration and it starts, logs cheerfully, and binds **only to localhost inside its own container**. Every client on your network gets *connection refused* against a broker that looks perfectly healthy. Upstream calls this local-only mode, and it's the single most reported Mosquitto-in-Docker problem.

`deploy.sh` always writes a `mosquitto.conf` with an explicit `listener`, which is what turns it off. You never see this failure here — it's documented so you recognise it if you ever run the image by hand.

**2. There is no authentication unless you build it.**

MQTT has **no per-topic permissions by default**. Anyone who can reach port 1883 on an anonymous broker can subscribe to *every* topic and publish to *every* topic. On a broker driving Home Assistant that means reading every sensor in your house and switching every device in it.

`deploy.sh` generates a password file and sets `allow_anonymous false`. That's why there's a username and password at all — the bare image has neither.

---

## 📥 Installation

### 1. Install prerequisites (if not already done)

```bash
curl -fsSL -o install_dockhub.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/install_dockhub.sh
sudo bash install_dockhub.sh
```
Pick **`1) Install / manage core infrastructure`** from the menu it shows.

### 2. Deploy Mosquitto

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Home-Automation/mosquitto/deploy.sh
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Home-Automation/mosquitto/docker-compose.yml
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group.

Single-instance, under `~/docker/mosquitto/`.

| Question | Notes |
|---|---|
| WebSocket listener | Optional, default **no**. Only needed for MQTT clients running *in a browser*. |
| Memory limit | Optional, suggested `128m` — generous for this broker. |

There's **no domain question**, because there's nothing for a reverse proxy to serve. The MQTT port is published on the host directly.

Credentials are generated into `~/docker/mosquitto/.mosquitto-docker-secrets.txt` (`600`):

```bash
cat ~/docker/mosquitto/.mosquitto-docker-secrets.txt
```

> 🔐 **That file is the only copy.** Mosquitto stores a *hash* of the password, so it cannot be recovered from the container. Lose the file and the fix is to reset the password (below), not to look it up.

---

## 🩺 Verify it actually works

A broker that starts is not the same as a broker that accepts connections — a bad password file, a listener on the wrong interface, or a config typo all leave a **running container that refuses every client**. And unlike every other service in this repo, there's no page to open that would show you.

**`deploy.sh` now tests this for you** and prints the result:

```
✅ Self-test passed — published and received a message over MQTT.
```

If it doesn't pass, the script prints the broker log command and the manual commands to repeat the test.

### Running it by hand

```bash
cd ~/docker/mosquitto
P=$(awk -F': ' '/MQTT password:/{print $2; exit}' .mosquitto-docker-secrets.txt)
docker exec mosquitto mosquitto_pub -h localhost -u mqtt -P "$P" -t dockhub/selftest -m 'it works' -r
docker exec mosquitto mosquitto_sub -h localhost -u mqtt -P "$P" -t dockhub/selftest -C 1 -W 5
docker exec mosquitto mosquitto_pub -h localhost -u mqtt -P "$P" -t dockhub/selftest -n -r
```

The subscriber prints `it works`. The last line clears the retained message so it doesn't sit in the broker forever.

> 💡 **Why publish before subscribing?** The `-r` flag marks the message *retained*: the broker keeps the last retained message per topic and hands it to any new subscriber the moment it connects. That turns the test into plain sequential commands. The obvious alternative — backgrounding a subscriber with `&` and then publishing — races the two against each other and fails intermittently for no visible reason.

### Reading the failure

| What you see | What it means |
|---|---|
| `Connection Refused: not authorised` | Wrong username or password. |
| `Connection refused` / timeout | The broker isn't listening — check `docker compose logs mosquitto`. |
| Works locally, fails from another machine | A firewall on the host, not Mosquitto. |

---

## 🔌 Connecting clients

| Client | Host to use |
|---|---|
| Another Docker container on `main-net` | `mosquitto` port `1883` |
| [Home Assistant](../home-assistant/) (host networking in this repo) | your server's LAN IP, port `1883` |
| ESP devices, sensors, phone apps | your server's LAN IP, port `1883` |

Username `mqtt`, password from the secrets file.

> 📌 **Nothing to point NGINX Proxy Manager at.** MQTT is a protocol, not a website — there is no web interface, and NPM proxies HTTP. This is the same situation as [Pi-hole](../../DNS/pi-hole/)'s DNS port and [WireGuard](../../VPN/wireguard/)'s UDP port.

### Exposing MQTT outside your LAN

Don't, unless you've thought it through. If you need remote devices to reach the broker, put them on a VPN ([WireGuard](../../VPN/wireguard/) or [NetBird](../../VPN/netbird/), both in this repo) rather than forwarding 1883 from your router. Plain MQTT is unencrypted — the password crosses the wire in the clear, and so does every message.

---

## 👥 Adding more users

Each device can have its own credentials. Add one:

```bash
docker exec -it mosquitto mosquitto_passwd -b /mosquitto/config/passwd newuser 'their-password'
```

```bash
docker exec mosquitto kill -HUP 1
```

The second command makes Mosquitto reload the password file without dropping existing connections.

To **reset** a forgotten password, use the same command with the existing username — it overwrites the entry.

To remove a user: `docker exec mosquitto mosquitto_passwd -D /mosquitto/config/passwd olduser`, then reload.

---

## ⚙️ Custom configuration

`~/docker/mosquitto/config/mosquitto.conf` is **generated by `deploy.sh` and regenerated on every run** — hand edits are lost.

Mosquitto loads *every* `.conf` file in that directory, so put your own directives in a second file instead:

```bash
nano ~/docker/mosquitto/config/local.conf
```

```bash
cd ~/docker/mosquitto && docker compose restart
```

That file survives reruns. Useful things to put there: `max_connections`, per-listener settings, bridge configuration to another broker, or an ACL file for real per-topic permissions.

> 💡 **Per-topic permissions** need an ACL file (`acl_file`), which this deployment doesn't set up — every authenticated user can currently read and write every topic. Fine for a household; worth configuring if devices you don't fully trust share the broker. See [Mosquitto's documentation](https://mosquitto.org/man/mosquitto-conf-5.html).

---

## 🛠️ Management Commands

```bash
cd ~/docker/mosquitto
```

| Command | Purpose |
|---|---|
| `docker compose ps` | Check the container |
| `docker compose logs -f` | Follow the broker's log (connections, auth failures) |
| `docker compose restart` | Reload after editing a config file |
| `docker compose pull && docker compose up -d` | Update within the pinned `2.1-alpine` line |

Logs go to **stdout** (`log_dest stdout`), so `docker compose logs` shows connection and authentication events as they happen — which is how you diagnose a device that won't connect.

---

## 💾 Backups

The repo's generic **Backup** covers this service, and no `backup.sh` override is needed — there's no database. It captures `~/docker/mosquitto/` (including `config/`, so your `mosquitto.conf`, any `local.conf`, and the password file) plus the data and log volumes.

The `mosquitto-data` volume holds retained messages and persistent subscriptions. Losing it doesn't lose configuration — devices simply republish.

---

## 📌 Notes & Deviations

- **The password file is created by a throwaway root container** which then `chown`s it to uid **1883**, the user Mosquitto drops to. Written by the host user it would be unreadable to the broker; made world-readable to work around that, Mosquitto logs a deprecation warning and future versions will refuse to load it outright.
- **Port 1883 is always published** — a broker nothing can connect to is pointless. The container *also* joins `main-net` so other containers can reach it as `mosquitto:1883` without leaving Docker.
- **The WebSocket listener is opt-in**, where many example configs enable it unconditionally. It only serves browser-based MQTT clients, and an unused open port is an unused open port.
- **`log_dest stdout`** instead of Mosquitto's default log file, so `docker compose logs` is useful.
- **No TLS listener.** Mosquitto supports MQTTS on 8883 with your own certificates; that needs a certificate lifecycle this deployment doesn't manage. The VPN route above is the simpler answer for remote access.
- **Pinned to `2.1-alpine`, not `2.1`.** There is no bare `2.1` tag — the 2.1 line ships only `-alpine` and `-ubuntu` variants, and bare tags stop at `2.0.22`. This isn't a niche choice: `latest`, `2` and `2.1-alpine` all resolve to the same image digest.

---

## 📜 License

Eclipse Mosquitto is licensed separately (EPL-2.0 / EDL-1.0 — see the [official repository](https://github.com/eclipse-mosquitto/mosquitto)). This deployment wrapper follows the same [MIT license](../../../LICENSE) as the rest of this repo.
