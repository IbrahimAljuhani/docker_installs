# 🚧 WebGoat

**Status:** Not built yet — coming soon.

[WebGoat](https://owasp.org/www-project-webgoat/) — OWASP's guided lesson-based teaching application. Where Juice Shop is a free-form target, WebGoat walks you through each vulnerability class with instructions and hints. Ships alongside WebWolf, its companion attacker-side tool.

Part of the **Security-Lab** category in [DockHub](../../../README.md)'s services roadmap. It's already listed in [`services.sh`](../../services.sh)'s menu (shows "coming soon" if picked) and in [`services/README.md`](../../README.md)'s roadmap table — this folder is just a placeholder until it's actually built.

---

## ⚠️ This category is different from every other one here

Security-Lab services are **vulnerable on purpose**. They are training targets, and their flaws are real and exploitable — not simulated.

That changes the deployment rules, and these will be the only services in this repo built this way:

- **No `main-net`.** Every other service joins the shared network so NGINX Proxy Manager can reach it by name. These will not: a container on `main-net` can reach NetBird's admin API, Vaultwarden, and every database container by name. A deliberately vulnerable app on that network is a foothold into the rest of your stack.
- **No public domain, no Let's Encrypt.** LAN-only, via a host port.
- **Off when you're not using them.** `docker compose stop` between sessions, not left running.

Deploy these on a machine you can afford to rebuild, and never on the same host as anything you care about.

Want to help build this one, or need it sooner? Open an issue on the [DockHub repo](https://github.com/IbrahimAljuhani/dockhub).
