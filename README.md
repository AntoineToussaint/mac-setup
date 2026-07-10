# mac-setup

Reproducible macOS developer setup for Apple Silicon — Homebrew packages, dotfiles, language runtimes, and Nix.

## Setup / Usage

```bash
bash ~/mac-setup/setup.sh                 # setup + update + security hardening (idempotent)
bash ~/mac-setup/setup.sh --no-security   # skip the security hardening step
bash ~/mac-setup/setup.sh --help          # usage
bash ~/mac-setup/security.sh              # security hardening alone (also run by setup.sh)
bash ~/mac-setup/doctor.sh                # validate the setup (read-only, no sudo)
```

One command does it all, and it's re-runnable: installs anything missing,
upgrades what's already there (`brew upgrade`, `mise upgrade`, Determinate Nix
upgrade), and applies security hardening — **secure by default**; the only flag
is to opt out.

What it does:

1. **Homebrew** — `brew update` + `brew bundle` from the [`Brewfile`](Brewfile), then `brew upgrade`.
2. **Dotfiles** — symlinks `dotfiles/*` into `~` (existing real files are backed up to `*.bak-<timestamp>`).
3. **Runtimes** — installs and upgrades node/python/go/rust via [mise](https://mise.jdx.dev), plus rustup components and Go's `air`.
4. **Nix** — Determinate Systems installer / upgrade (not via Homebrew).
5. **Security** — runs [`security.sh`](security.sh): firewall + stealth, auto-updates, npm `ignore-scripts`, Touch ID for sudo (skip with `--no-security`).

After a first run: restart your terminal (`exec zsh`), set Ghostty as default, and `gh auth login`.

To verify everything took, run [`doctor.sh`](doctor.sh) — it checks the hardening,
dotfile symlinks, Brewfile, runtimes, and credentials, and lists any manual
follow-ups still unchecked in [`TODO.md`](TODO.md).

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
| Egress | See + block outbound traffic per app/domain | Little Snitch (Brewfile) — Alert Mode for a few days, then rules |
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

## Shell Shortcuts

A curated set of zsh aliases and functions worth adding to `dotfiles/zshrc`.

These are chosen to **complement** what's already configured, not repeat it. The current setup already gives you:

- **zoxide** — `cd` is aliased to `z` (smart jump); `zi` opens an interactive, searchable cd-history picker
- **fzf** — `Ctrl+R` fuzzy history search, `Ctrl+T` fuzzy file picker
- **eza** — `ls`, `ll`, `lt` (tree); **bat** for `cat`; **nvim** for `vim`; **lazygit** for `lg`; **rg** for `grep`
- **Nav** — `..`, `...`, `....`, `AUTO_CD`, `reload`
- **git** — full alias set from the antidote/OMZ git plugin
- **History** — shared across sessions, prefix search on `Up`/`Down`

---

## Quick exits & basics

```zsh
alias x='exit'
alias c='clear'
```

## Directory navigation

```zsh
# bd <name>: jump UP to an ancestor directory whose name matches <name>
bd() { cd "$(pwd | sed "s|\(.*/$1[^/]*/\).*|\1|")"; }

# mkcd <dir>: make a directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# toggle back to the previous directory
alias -- -='cd -'
```

> Note: for cd **history**, zoxide's `zi` already gives you an interactive fuzzy picker — no custom function needed.

## History

```zsh
alias h='history'
alias hg='history | rg'   # search shell history: hg <pattern>
```

## Extract any archive

```zsh
extract() {
  case "$1" in
    *.tar.gz|*.tgz) tar xzf "$1"   ;;
    *.tar.bz2)      tar xjf "$1"   ;;
    *.tar)          tar xf "$1"    ;;
    *.gz)           gunzip "$1"    ;;
    *.zip)          unzip "$1"     ;;
    *)              echo "extract: unknown format '$1'" ;;
  esac
}
```

## Ports & processes

```zsh
# list everything listening on a TCP port
alias ports='lsof -iTCP -sTCP:LISTEN -nP'

# killport <port>: kill whatever is bound to a port (e.g. killport 3000)
killport() { lsof -ti tcp:"$1" | xargs kill -9; }
```

## Global aliases (pipe helpers)

Global aliases expand anywhere on the line, so you can tack them onto any pipe:

```zsh
alias -g G='| rg'      # ... G pattern    -> pipe into ripgrep
alias -g L='| less'    # ... L            -> pipe into less
alias -g H='| head'    # ... H            -> pipe into head
```

Example: `ll G config`, `cat file L`, `dmesg H`.

## fzf helpers

```zsh
# fcd: fuzzy-pick a subdirectory and cd into it
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)"; }
```

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

## Sources

- [Towards The Cloud — zsh aliases](https://towardsthecloud.com)
- [SitePoint — 75 Zsh commands, plugins & aliases](https://www.sitepoint.com/zsh-tips-tricks/)
- [Stupid ZSH tricks — thenybble.de](https://thenybble.de)
- [DEV — Useful aliases for ZSH](https://dev.to)
