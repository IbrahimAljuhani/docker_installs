# ☁️ Using Cloudflare Tunnel with DockHub

If your server is at home (no public IP, or behind CGNAT/ISP restrictions), Cloudflare Tunnel is the recommended alternative to router port-forwarding: no inbound ports need to be opened at all. This guide covers the setup pattern specific to how DockHub is structured — install/create the tunnel yourself (not automated by `install_dockhub.sh`), then follow the routing convention below for every service.

If you chose "Cloudflare Tunnel" when `install_dockhub.sh` asked about your environment, this is the guide it pointed you to.

---

## The core idea

```
Visitor → Cloudflare edge (HTTPS) → cloudflared (on your server) → NPM (port 80) → the service's own container (by name, over main-net)
```

**`cloudflared` always routes to NPM — never directly to a service's container.** NPM is what decides, based on the domain in the request, which service to forward to. This is exactly the same role NPM already plays for a normal DNS setup; Cloudflare Tunnel just replaces "point your domain's A record at your public IP" with "route the domain through the tunnel to this server instead."

---

## One-time setup

1. Install `cloudflared` on your server (not automated by this repo — see [Cloudflare's own install docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/) for your OS).
2. Authenticate and create a tunnel: `cloudflared tunnel login`, then `cloudflared tunnel create <name>`.
3. Run it as a service (Cloudflare's docs cover `cloudflared service install`, or run it as its own Docker container — either works, DockHub doesn't require one over the other).

---

## Per-service routing (do this for every service you deploy)

In the Cloudflare Zero Trust dashboard → **Networks → Tunnels → your tunnel → Public Hostname**, add a route:

| Field | Value |
|---|---|
| Subdomain / Domain | whatever domain you want this service on (e.g. `jellyfin.example.com`) |
| Service Type | `HTTP` |
| URL | `<server-ip>:80` — **NPM's port, always**, regardless of which service this domain is for |

Then set up the matching Proxy Host in NPM as normal, following that service's own README "Reverse Proxy" section (forward to `<service>-app`, the actual container port, etc.) — the only thing Cloudflare Tunnel changes is how traffic *reaches* NPM, not anything about how NPM itself is configured internally.

### Critical: leave Force SSL OFF in NPM for tunnel-routed domains

`cloudflared` delivers traffic to NPM over **plain HTTP** by design — Cloudflare's edge already terminates HTTPS for the visitor, so that hop doesn't need to be encrypted again. If you enable **Force SSL** on the NPM Proxy Host, NPM tries to redirect that already-plain-HTTP request to HTTPS, which fights with Cloudflare's own HTTPS enforcement and creates a redirect loop.

**Symptom**: `400 Bad Request — Request Header Or Cookie Too Large`. This looks like a cookie/header-size problem but is actually the redirect loop — each iteration stacks another round of headers until nginx rejects the request.

**Leaving Force SSL off is not a security downgrade** — Cloudflare's edge still enforces HTTPS to every visitor regardless of what NPM does internally.

---

## Verifying it's working

```bash
# Confirm the tunnel is actually connected
docker logs <cloudflared-container-name> --tail 20

# Confirm NPM is listening where the tunnel expects
docker ps --filter name=npm-app-1 --format "table {{.Names}}\t{{.Ports}}"
```

If a specific domain isn't reachable, check `cloudflared`'s logs for the exact address it tried to reach — `dial tcp <ip>:<port>: connect: connection refused` tells you immediately whether the route is pointed at the wrong place (see the per-service routing table above).

For anything else, see [troubleshooting.md](troubleshooting.md)'s Cloudflare Tunnel checklist.
