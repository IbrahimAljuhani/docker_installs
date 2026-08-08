# 💥 Vulhub

> ⚠️ **This one is different from everything else in DockHub, including the rest of Security-Lab.** Read [`services/Security-Lab/README.md`](../README.md) first.

[Vulhub](https://github.com/vulhub/vulhub) is a library of roughly **330 pre-built environments**, each reproducing a real, published CVE — Log4Shell, Struts RCE, Confluence OGNL injection, and so on — with a write-up explaining exactly why the flaw works.

---

## 🖥️ It needs its own machine. This is a requirement, not advice.

`deploy.sh` **refuses to run** on a host where the `main-net` network exists, because that network is created by `install_dockhub.sh` and its presence means you are on the machine carrying your real services.

Two reasons, and the second is the one that decided it:

**1. The exploits are a different class.** [Juice Shop](../juice-shop/) and [WebGoat](../webgoat/) have flaws in their *application logic*: you attack them through a browser, and a successful exploit gets you a session in a web app. A Vulhub exploit is typically **unauthenticated remote code execution** — it puts an attacker inside the container immediately, with no login and no browser.

**2. The hardening cannot be applied.** Every other Security-Lab service uses a compose file this repo wrote: `cap_drop: ALL`, `no-new-privileges`, `pids_limit`, a LAN-bound port. Vulhub's 330 compose files belong to **upstream**. Some run `privileged`, some use host networking, and they publish on all interfaces:

```yaml
# vulhub/log4j/CVE-2021-44228/docker-compose.yml — upstream's, not ours
ports:
 - "8983:8983"
```

Applying our hardening would mean forking hundreds of files that change with every update to the library. So we don't pretend to: the honest answer is a machine you can wipe.

> A spare laptop, an old mini-PC, or a throwaway VM all work. If you genuinely accept the risk anyway, `--allow-production-host` exists — but it is a decision, not a workaround.

---

## 📥 Usage

This is a **launcher**, not a deployment. There is no `docker-compose.yml` of ours, no `.env`, and nothing to keep running.

```bash
curl -fsSL -o deploy.sh \
  https://raw.githubusercontent.com/IbrahimAljuhani/dockhub/main/services/Security-Lab/vulhub/deploy.sh
bash deploy.sh
```

> ⚠️ **Do not run as root.** Your user must be in the `docker` group. `git` is also required.

What happens:

1. **Host check** — refuses if `main-net` exists.
2. **`I-UNDERSTAND`** confirmation.
3. **Shallow clone** of the Vulhub library into `~/docker/vulhub/vulhub` (about 100 MB), or a `git pull` if it's already there. Submodules are included — `base/oracle-java` is one, and a few Java environments fail confusingly at build time without it.
4. **Search** for an environment. 330 entries is not a list anyone reads, so you type a keyword instead:

```
Search for an environment (e.g. log4j, struts2, tomcat): log4j

   1) log4j/CVE-2017-5645
   2) log4j/CVE-2021-44228
   0) Search again
```

5. **The write-up is shown** before anything starts — it's the actual learning material; the container is just the target.
6. **Start**, then the published ports are listed.

---

## 🔁 One environment at a time

The launcher tracks what's running in `~/docker/vulhub/.current-environment` and offers to stop it before starting another.

This isn't tidiness. Vulhub's environments reuse the obvious ports — 8080, 8983, 3306 — constantly, so a second one usually collides with the first, and the symptom is *the exploit appearing not to work* rather than an obvious port error.

To stop by hand:

```bash
cd ~/docker/vulhub/vulhub/<environment> && docker compose down
```

---

## 📖 How to actually learn from it

Each environment ships a `README.md` with the vulnerability's background, references, and a worked exploitation walkthrough. **Read it before attacking.** Vulhub's value is the explanation of *why* the CVE works — the running container is just something to point it at.

```bash
cat ~/docker/vulhub/vulhub/log4j/CVE-2021-44228/README.md
```

A reasonable loop: read the write-up, reproduce it exactly, then try to reach the same result a different way.

---

## 🛠️ Management

| Command | Purpose |
|---|---|
| `bash deploy.sh` | Stop the current environment and/or pick a new one |
| `docker ps` | What's actually running |
| `cd ~/docker/vulhub/vulhub && git pull` | Update the library |
| `rm -rf ~/docker/vulhub` | Remove everything (stop the running environment first) |

---

## 📌 Notes & Deviations

- **No `docker-compose.yml` of ours, and no `.env`.** Every environment brings its own, written by upstream. This is the only entry in DockHub where that's true.
- **No memory or PID limits, no dropped capabilities.** Not an oversight — see the section at the top. We do not control these compose files, and claiming otherwise would be worse than saying so plainly.
- **No `restart:` policy of ours either**, so an environment's own policy applies. Stop what you start.
- **No backup.** There is nothing here that is yours.
- **Shallow clone** (`--depth 1`): the full history is roughly 180 MB and none of it is useful for running the environments.

---

## 📜 License

Vulhub is licensed separately (MIT — see the [official repository](https://github.com/vulhub/vulhub)). Individual environments bundle third-party software under their own licences. This launcher follows the same [MIT license](../../../LICENSE) as the rest of DockHub.
