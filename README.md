# mac-setup

Reproducible macOS developer setup for Apple Silicon — Homebrew packages, dotfiles, language runtimes, and Nix.

## Install

On a brand-new Mac, paste this into Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AntoineToussaint/mac-setup/main/bootstrap.sh)"
```

[`bootstrap.sh`](bootstrap.sh) only closes the gap a fresh Mac leaves — Xcode
Command Line Tools (for `git`), Homebrew, and cloning this repo to `~/mac-setup`
— then hands off to [`setup.sh`](setup.sh), which does the real work. It is
re-runnable: a second run updates the clone instead of failing, and leaves local
edits alone.

Options after `--` are passed through, e.g. a sudo-free run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AntoineToussaint/mac-setup/main/bootstrap.sh)" -- --user-only
```

Prefer to read before you run? That is the sensible instinct with any
`curl | bash` — clone it and look first:

```bash
git clone https://github.com/AntoineToussaint/mac-setup.git ~/mac-setup
bash ~/mac-setup/setup.sh
```

`MAC_SETUP_DIR` clones somewhere other than `~/mac-setup`; `MAC_SETUP_REF`
checks out a branch other than `main`.

## Setup / Usage

```bash
bash ~/mac-setup/setup.sh                 # full update + hardening + verification
bash ~/mac-setup/setup.sh --user-only     # Homebrew/dotfiles/mise; no sudo
bash ~/mac-setup/setup.sh --no-security   # update Nix but skip security hardening
bash ~/mac-setup/setup.sh --help          # usage
bash ~/mac-setup/security.sh              # security hardening alone
bash ~/mac-setup/doctor.sh                # standalone read-only verification
```

One command does it all, and it's re-runnable: installs anything missing,
upgrades what's already there (`brew upgrade`, `mise upgrade`, Determinate Nix
upgrade), applies security hardening, and verifies the result. It is **secure by
default**; use `--user-only` when you explicitly want a sudo-free update.

What it does:

1. **Homebrew** — `brew update` + `brew bundle` from the [`Brewfile`](Brewfile), then `brew upgrade`.
2. **Dotfiles** — symlinks `dotfiles/*` into `~` (existing real files are backed up to `*.bak-<timestamp>`).
   Your git identity is *not* in the tracked `dotfiles/gitconfig` — it asks once and writes
   `~/.config/git/identity`, which that file `[include]`s. Change it with `--reconfigure`.
   Commit signing is only switched on if you ask for it and 1Password's `op-ssh-sign` is present.
3. **Runtimes** — installs and upgrades node/python/go/rust via [mise](https://mise.jdx.dev), plus rustup components and Go's `air`.
4. **Nix** — Determinate Systems installer / upgrade (not via Homebrew).
5. **Security** — runs [`security.sh`](security.sh): firewall + stealth, auto-updates, npm `ignore-scripts`, Touch ID for sudo (skip with `--no-security`).
6. **Verification** — runs [`doctor.sh`](doctor.sh) and exits non-zero if a machine-checkable requirement fails.

At the end, `setup.sh` prints only authentication or identity follow-ups that
live checks show are still needed.

### Raycast extensions

Raycast extensions cannot be installed by script, and `brew bundle` cannot
restore them. They live in Raycast's own store plus an encrypted SQLite database
(`raycast-enc.sqlite`, key in the Keychain), so copying the support directory to
a new Mac does not work. The web store's *Install Extension* button resolves to
`raycast://extensions/<author>/<extension>?source=webstore`, but invoking that
with `open` does nothing outside the browser handoff — tested, no install.

What does work is Raycast's own export/import, which is free (Cloud Sync, the
continuous alternative, is Pro-only):

1. On a Mac that is already set up, run Raycast's **Export Settings & Data**
   command and choose a passphrase (8+ characters). It writes a `.rayconfig`
   bundling 11 categories — one of which is *Extensions installed from the Store*.
2. Save that file to `~/mac-setup/raycast/` or point `RAYCAST_CONFIG` at it.
   **Never commit it**: the same bundle carries clipboard history, notes and AI
   chats. `.gitignore` excludes `raycast/` and `*.rayconfig` — keep it in
   1Password or iCloud instead.
3. On the new Mac, `setup.sh` finds it and runs `open` on it, which lands
   directly in Raycast's import dialog (Raycast owns the `.rayconfig` file type).
   Enter the passphrase and tick at least *Extensions installed from the Store*.

That last step is manual by necessity — nothing in Raycast accepts a passphrase
non-interactively. Once offered, a stamp at `~/.config/mac-setup/raycast-imported`
stops it repeating; delete the stamp to be asked again.

Note that a `.rayconfig` is an encrypted blob, **not** a reviewable manifest: it
cannot be diffed or hand-edited to add one extension, unlike the `Brewfile`.
Raycast exposes no plain-text extension list.

### Setapp apps

A Setapp subscription is invisible to `brew bundle` — the apps live under
`/Applications/Setapp/`, installed by Setapp's own agent — so a fresh Mac starts
with an empty Setapp folder even after a full `setup.sh` run. Unlike Raycast,
this one is fully scriptable, via [`Setappfile`](Setappfile) and
[`bin/setapp-sync`](bin/setapp-sync):

```bash
setapp-sync export        # refresh Setappfile from what is installed here
setapp-sync list          # what the Setappfile holds, ✓ = already installed
setapp-sync install       # install everything missing (confirm each panel)
setapp-sync install -n    # ...dry run: print the deeplinks instead
setapp-sync export --prune # ...and forget the wanted list
```

The manifest has two sections. **installed** is regenerated from this Mac on
every `export`. **wanted** is a wishlist — apps chosen but not installed here —
and `export` carries it forward instead of dropping it, so hand-added picks
survive a re-export. An app moves from *wanted* to *installed* on its own once it
is actually on the machine and you re-export. `install` fetches both sections.

`setup.sh` offers `install` automatically when `Setappfile` lists apps that are
not on the machine. Setapp must be installed (`cask "setapp"` is in the
[`Brewfile`](Brewfile)) and **signed in** first.

Two undocumented pieces make it work:

1. The desktop client caches the whole catalogue in a Core Data store at
   `~/Library/Application Support/Setapp/Default/Databases/Apps.sqlite`. Its
   `ZAPP` table maps each app's bundle identifier to a public UUID (`ZPUBLICID`,
   a raw 16-byte blob). `export` reads a copy of the database — it is open in WAL
   mode, so the `-wal` file has to come along — and joins it against the bundle
   ids actually present under `/Applications/Setapp/`.
2. `SetappAgent` registers the `setapp:` URL scheme, and its `InstallAppFromURL`
   handler accepts `setapp://install?app_id=<UUID>` — the dashed, uppercase form
   of that same `ZPUBLICID`. Nothing else is accepted: the numeric
   `ZIDENTIFIER`, `app_name=`, and a `launch` host are all logged as *"URL is not
   a valid install-from-URL link"*. The agent also refuses to start a second
   install while one is running, so `install` fires one deeplink at a time and
   waits for the bundle to appear (`SETAPP_INSTALL_TIMEOUT`, default 600s).

Because the UUIDs are written into `Setappfile`, restoring does **not** depend
on the catalogue cache being populated on the new Mac. The file is a plain
tab-separated manifest — reviewable, diffable, and safe to commit (it holds app
names and public ids, no account data), so unlike a `.rayconfig` you can add an
app to it by hand.

`setup.sh` runs [`doctor.sh`](doctor.sh) automatically. You can also run it
standalone at any time; it checks hardening, dotfile symlinks, the Brewfile,
runtimes, and credentials, then lists unchecked manual items from [`TODO.md`](TODO.md).

---

## Security

Threat model: for a developer, realistic attacks are things that **run code as you** —
malicious browser extensions, npm/pip packages with install scripts, cloned repos you
build. Disk encryption doesn't help there; limiting what's readable and usable does.

Layers (mostly automated by [`security.sh`](security.sh) + the Brewfile's Security section):

| Layer | What | How |
|---|---|---|
| Credentials | SSH keys + commit signing never on disk | 1Password SSH agent + `op-ssh-sign` (in `dotfiles/gitconfig`); per-use biometric approval |
| Credentials | Phishing-proof 2FA | Hardware key (YubiKey) on GitHub / Google / cloud — manual |
| Supply chain | npm install scripts disabled globally | `security.sh` (`ignore-scripts=true`; pnpm ≥10 and bun already block by default) |
| Supply chain | Untrusted code off the bare machine | Run interview projects / unknown repos in OrbStack containers |
| Egress | Block known-bad domains system-wide | [NextDNS](https://nextdns.io) with threat-intel feeds — manual, account-based |
| Detection | Persistence + mic/camera alerts | BlockBlock, KnockKnock, OverSight (Brewfile) |
| OS | Firewall + stealth, auto-updates, Touch ID sudo | `security.sh` |
| OS | FileVault / SIP / Gatekeeper must be on | `security.sh` reports status; fix in System Settings |

Rules of thumb:

- **Browser extensions are code with access to everything you browse.** Keep the count
  minimal, audit occasionally (`chrome://extensions`), prefer open-source ones.
  (This repo exists partly because ModHeader v7.0.18 shipped spyware in July 2026.)
- **No long-lived plaintext tokens on disk** — prefer Keychain/1Password (`op run`,
  direnv pulling from `op`) over `.env` files with real secrets.
- **Assume breach**: Time Machine + offsite backup; rotate anything that may have leaked.

---

## Shell cockpit

The managed Zsh setup is split by lifecycle: `zshenv` contains quiet universal
environment defaults, `zprofile` initializes login-shell tooling, `zshrc`
configures the interactive shell, and `shortcuts.zsh` owns curated functions.

### Navigation

- `cd path` — standard Zsh directory navigation; it is deliberately not aliased.
- `z name` / `zi` — zoxide smart jump and interactive fuzzy history.
- `-` or `cd -` — toggle back to the previous directory.
- `..`, `...`, `....` — move up one, two, or three directories.
- `bd name` — jump up to the nearest ancestor whose name starts with `name`.
- `fcd [root]` — fuzzy-select a subdirectory, excluding `.git`, `node_modules`, and `target`.
- `mkcd dir` — create a directory and enter it.
- `y` — browse with Yazi and keep its final directory when it exits.

### Finding, completion, and history

- `Ctrl+R` — Atuin history search; `Up`/`Down` retain prefix search.
- `Ctrl+T` — fzf file/directory picker with `bat`/`eza` preview.
- `Alt+C` — fzf directory picker with tree preview.
- `Tab` — fzf-tab completion for commands, options, files, branches, and other Zsh completions.
- `Ctrl+X Ctrl+E` — edit the current command line in `$EDITOR` (Neovim).
- `rg` remains explicit rather than replacing `grep`; `h` and `hg` expose native history.

### Utilities

- `ls`, `ll`, `lt` use eza; `cat` uses bat; `vim` uses Neovim; `lg` opens lazygit.
- `ports` lists TCP listeners; `killport PORT` sends TERM and `killport --force PORT` sends KILL.
- `extract ARCHIVE` validates and extracts common tar, gzip, bzip2, xz, and zip formats.
- Global aliases `G`, `L`, and `H` append `| rg`, `| less`, and `| head` to a command.
- Commands consuming at least five CPU seconds automatically print a timing summary.

### Shell Coach

`shell-coach` (or `coach`) reviews recent Atuin history and ranks concrete ways
to use the modern tools already installed by this setup:

```zsh
coach                       # local deterministic analysis of 1,000 commands
coach --limit 2500 --all    # deeper scan, every qualifying suggestion
coach --llm                 # add an optional local LM Studio review
coach --show-llm-prompt     # inspect the exact anonymized prompt, no model call
```

The rule engine processes command text locally and does not persist it. The
optional LLM receives only aggregate command skeletons such as `git status ×18`:
paths, arguments, values, URLs, headers, credentials, and raw history are never
included. The first installed LM Studio LLM is selected automatically, or choose
one explicitly with `--model MODEL`. Rule-based cards include a representative
pattern, copy/paste examples, and when the familiar command is still the better
choice; the LLM is asked to follow the same evidence/example/caveat structure.

### Public dev tunnel (`devtunnel`)

`devtunnel` puts a local dev server behind a **fixed** public HTTPS hostname
using a Cloudflare *named* tunnel. This is the difference that matters: a quick
tunnel (`cloudflared tunnel --url http://localhost:3000`) mints a new random
`*.trycloudflare.com` URL on every start, which is useless for OAuth redirect
URIs, webhook registrations, or a phone pinned to one address. A named tunnel is
a persistent object with a CNAME you own, so the hostname survives restarts,
reboots, and reinstalls.

**Requires** a domain whose nameservers point at Cloudflare (free plan is fine);
the fixed hostname is a record in that zone.

```zsh
devtunnel check dev.yourdomain.com  # is the zone on Cloudflare yet?
devtunnel login                     # once per machine — browser auth
devtunnel up dev.yourdomain.com 3000 # create tunnel + DNS route, then run it
devtunnel run dev.yourdomain.com    # later runs: no DNS changes
devtunnel ls                        # configured hostnames + targets
devtunnel rm dev.yourdomain.com     # delete the tunnel
```

#### Moving a domain registered elsewhere

If the domain is at another registrar, only its **nameservers** move — the
registration, and where you pay for it, stay put.

1. Add the domain at <https://dash.cloudflare.com> (free plan). Cloudflare scans
   the existing records and shows you two nameservers.
2. At your registrar, replace the current nameservers with that pair.
3. `devtunnel check dev.yourdomain.com` until it reports Cloudflare — usually
   minutes, occasionally a few hours. `up` cannot route the hostname before then.

`check` walks from the full hostname down to the delegation point, so it reports
the real zone apex (`bbc.co.uk`, not `co.uk`) and tells you which nameservers are
actually answering.

#### Tailscale Funnel — a stable URL with no domain

When the URL only has to be *stable*, not *yours*, skip DNS entirely:

```zsh
devtunnel funnel 3000 --guard   # serve localhost:3000, shared secret required
devtunnel funnel 3000           # same, but wide open — local experiments only
devtunnel funnel 3000 --bg      # detach instead of holding the terminal
devtunnel funnel url            # print just the URL — for CI secrets/config
devtunnel funnel pin            # record the URL so doctor catches drift
devtunnel token                 # print the shared secret
devtunnel funnel status / off
```

The hostname is `<machine>.<tailnet>.ts.net`, derived from the machine and
tailnet names, so it is stable until you rename one of them. HTTPS certificates
are issued automatically.

**Funnel is public and unauthenticated** — this is what makes it reachable from
GitHub-hosted CI runners, which are not on your tailnet. It is *not*
`tailscale serve`, which is tailnet-only. Anyone with the URL can reach the port,
so put your own auth in front of it: a shared-secret header, or signed webhook
payloads. Funnel also only listens publicly on ports 443, 8443, and 10000, and
Tailscale rate-limits it — it is for development traffic, not production.

##### The shared-secret gate (`--guard`)

Funnel has no authentication of its own, so `--guard` puts `bin/devtunnel-guard`
(stdlib Python, no dependencies) in front of the dev server:

```
internet -> Funnel :443 -> guard :8099 -> your app :3000
                            rejects anything without the token
```

The guard checks `X-Devtunnel-Token` in constant time, strips it before
forwarding (your app never sees the secret), passes upstream status codes
through unchanged, and returns 502 only when the app is genuinely unreachable.
It binds `127.0.0.1`, so nothing but Funnel can reach it. The token lives in
`~/.config/devtunnel/token` (mode 600) and is generated on first use; override it
per-run with `DEVTUNNEL_TOKEN`, or move the guard's port with
`DEVTUNNEL_GUARD_PORT`.

##### From a GitHub Actions workflow

```yaml
- name: Call the dev machine
  run: |
    curl -sS --fail-with-body --max-time 30 \
      -H "X-Devtunnel-Token: ${{ secrets.DEVTUNNEL_TOKEN }}" \
      "${{ secrets.DEVTUNNEL_URL }}/health"
```

Set the two secrets from `devtunnel funnel url` and `devtunnel token`. The tunnel
only answers while `devtunnel funnel` is running on the Mac and the machine is
awake, so a job fails fast rather than hanging — the better failure mode, but it
does make "start the tunnel" part of the dev loop.

##### Keeping the URL from changing

The URL is `<device>.<tailnet>.ts.net`. The tailnet half is stable; the device
half is derived from the macOS hostname, and re-registering a machine while the
old node still exists yields `<device>-1`. Either change breaks whatever CI has
stored, silently.

```zsh
devtunnel funnel pin    # record today's URL
```

`doctor.sh` then **fails** if the live URL no longer matches, and `devtunnel
funnel url` warns on stderr while still printing the real URL on stdout. Also
worth renaming the machine once in the Tailscale admin console — a name set there
stops tracking the macOS hostname.

#### Which backend?

| | Cloudflare (`up`) | Tailscale (`funnel`) |
|---|---|---|
| Hostname | `dev.yourdomain.com` | `<machine>.<tailnet>.ts.net` |
| Needs a domain | yes, zone on Cloudflare | no |
| Setup | move nameservers once | log into the app |
| Public ports | any | 443 / 8443 / 10000 |
| Auth options | Cloudflare Access | `--guard` shared secret |

`up` is idempotent — re-running reuses the existing tunnel and reasserts the DNS
record (`--overwrite-dns`), so it is the only command you normally need. Targets
accept a port (`3000`), a TLS port (`8443/https`, origin cert not verified since
dev servers are self-signed), or a full URL (`http://127.0.0.1:5000`). Each
hostname gets its own tunnel and a generated config at
`~/.cloudflared/dev-<hostname>.yml`, so several projects can run side by side.

Deleting a tunnel does not remove its CNAME — `cloudflared` can create DNS
records but never delete them, so drop it in the Cloudflare dashboard (DNS →
Records) or with `flarectl` and a Zone:DNS:Edit API token. A tunnel whose CNAME
outlives it answers 530 (error 1033) rather than NXDOMAIN.

##### Surviving reboots

`cloudflared service install` (no sudo — it installs a *user* launch agent,
which runs whenever you are logged in) is the right idea, but on macOS it
generates a plist whose `ProgramArguments` is the bare binary with **no
arguments**. Bare `cloudflared` just prints "use `cloudflared tunnel run`" and
exits, and `KeepAlive` restarts it forever. Point the agent at a real command:

```xml
<key>ProgramArguments</key>
<array>
  <string>/opt/homebrew/bin/cloudflared</string>
  <string>--config</string><string>/Users/you/.cloudflared/config.yml</string>
  <string>--no-autoupdate</string>
  <string>tunnel</string><string>run</string>
</array>
```

`~/.cloudflared/config.yml` can be a symlink to the per-hostname config
`devtunnel up` generates. Reload with `launchctl bootout gui/$(id -u)/…` then
`launchctl bootstrap gui/$(id -u) <plist>`.

The tunnel surviving a reboot is only half of it — the service it points at has
to come back too, or the hostname resolves, terminates TLS, and returns 502.

---

## Language tooling (2026 stack)

Wired into `Brewfile` / `setup.sh` so a fresh machine is reproducible.

| Lang | Tools | Notes |
|---|---|---|
| **Python** | `uv`, `ruff` | Astral stack. `uv` = pkg/project manager; `ruff` = linter+formatter. Type checker `ty` per-project via `uvx ty check`. Runtime from mise (`python@latest` = 3.14; use `mise use python@3.12` per-project when needed). |
| **Rust** | `rust-analyzer`, `clippy`, `rustfmt`, `bacon`, `cargo-nextest` | Toolchain via rustup (components ensured in `setup.sh`); `bacon` = watch/test loop; `cargo-nextest` = fast test runner. |
| **Go** | `gopls`, `golangci-lint`, `delve`, `air` | LSP + meta-linter + debugger (`dlv`); `air` (live reload) via `go install` → `~/go/bin`. |
| **JS/Next** | `biome`, `pnpm`, `bun` | Next 16 = Turbopack + TS by default; `biome` replaces ESLint+Prettier on new projects. |

Editors: `gram` (Zed fork), `cursor` (AI-first VS Code fork), `neovim`.
Compat-testing IDEs (installed, not daily drivers): `visual-studio-code`,
`zed` (upstream), `jetbrains-toolbox` (IntelliJ/PyCharm/GoLand/…), `sublime-text`.
Agent orchestration: `conductor` (parallel Claude Code agents in git worktrees).
Agent spend: `ccusage daily` / `monthly` prices the tokens Claude Code, Codex and
Gemini CLI burned at API rates — i.e. what the flat-rate subscriptions would have
cost in cash. Reads local JSONL logs only; nothing leaves the machine.
Local inference: `ollama` (CLI+server, native MLX runner on Apple Silicon since
0.19) with `ollama-app` as its GUI; `mlx-lm` for Apple's MLX directly (fastest on
Apple Silicon); `llama.cpp` for GGUF tooling; `lm-studio` for a GUI + headless server.

## Sources

- [Towards The Cloud — zsh aliases](https://towardsthecloud.com)
- [SitePoint — 75 Zsh commands, plugins & aliases](https://www.sitepoint.com/zsh-tips-tricks/)
- [Stupid ZSH tricks — thenybble.de](https://thenybble.de)
- [DEV — Useful aliases for ZSH](https://dev.to)
