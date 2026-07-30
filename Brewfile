# ~/mac-setup/Brewfile — run with: brew bundle --file=~/mac-setup/Brewfile
# Apple Silicon macOS developer setup.

# ---------- Terminal & shell ----------
cask "ghostty"                          # GPU-accelerated native terminal
cask "font-jetbrains-mono-nerd-font"    # Nerd Font: glyphs/icons for the prompt (default)
cask "font-meslo-lg-nerd-font"          # MesloLGS NF — the classic P10k/powerline font
cask "font-fira-code-nerd-font"         # FiraCode — programming ligatures
cask "font-caskaydia-cove-nerd-font"    # Cascadia Code — MS's editor font, ligatures
cask "font-monaspice-nerd-font"         # GitHub Monaspace — modern, texture healing
brew "starship"                         # cross-shell prompt (Rust, actively maintained)
brew "antidote"                         # zsh plugin manager (loads ~/.zsh_plugins.txt)
# NOTE: zsh-autosuggestions / zsh-syntax-highlighting / OMZ git plugin are now
# managed by antidote via ~/.zsh_plugins.txt, not installed as brew formulae.

# ---------- Modern CLI core ----------
brew "eza"          # ls replacement
brew "bat"          # cat with syntax highlighting
brew "glow"         # render markdown in the terminal (glow file.md)
brew "ripgrep"      # rg — fast grep
brew "fd"           # fast find
brew "fzf"          # fuzzy finder
brew "zoxide"       # smart cd (z)
brew "jq"           # JSON processor
brew "yq"           # YAML/XML processor
brew "btop"         # resource monitor
brew "tldr"         # simplified man pages
brew "tree"         # directory tree
brew "wget"         # downloader
brew "tmux"         # terminal multiplexer (latest stable via brew)
brew "just"         # command runner (Makefile replacement) — run `just <task>`
brew "hyperfine"    # CLI benchmarking tool
brew "watchexec"    # run a command whenever files change (language-agnostic)
brew "dust"         # friendlier du (disk usage)
brew "duf"          # friendlier df (disk free)
brew "procs"        # ps replacement (Rust) — tree view, colors, search
brew "sd"           # sed replacement — sane find/replace syntax
brew "atuin"        # magical shell history (SQLite, fuzzy Ctrl+R) — see zshrc init
brew "yazi"         # blazing terminal file manager (Rust)
brew "xh"           # httpie-style HTTP client (Rust) — REST from the terminal
brew "doggo"        # dig replacement — modern DNS client
brew "trippy"       # mtr/traceroute replacement (binary: trip)
brew "gping"        # ping with a live graph
brew "asciinema"    # record/share terminal sessions

# ---------- Git ----------
brew "git"
brew "gh"           # GitHub CLI
brew "lazygit"      # git TUI
brew "git-delta"    # better git diffs
brew "difftastic"   # structural (syntax-aware) diffs — complements delta (binary: difft)
brew "git-absorb"   # auto-generate fixup! commits into the right ancestor
# gh-dash (PR/issue TUI dashboard) is a gh extension, not a formula — installed in setup.sh
brew "schpet/tap/linear"  # Linear CLI — git/gh-aware: start issues as branches, open PRs, agent-friendly

# ---------- Dev environment ----------
cask "orbstack"     # Docker / Linux VMs (light Docker Desktop replacement)
brew "lazydocker"   # Docker/container TUI (like lazygit, for containers)
brew "dive"         # inspect Docker image layers & contents
brew "mise"         # runtime/version manager (node, python, go, rust)
brew "neovim"       # editor
brew "direnv"       # per-directory environment variables
brew "cloudflared"  # Cloudflare Tunnel — public HTTPS reverse proxy to localhost.
                    # Use `devtunnel` (bin/devtunnel) for a FIXED hostname via a
                    # named tunnel; bare `cloudflared tunnel --url` only ever gives
                    # a throwaway random *.trycloudflare.com URL.
cask "tailscale-app" # Tailscale (GUI app; the cask formerly named "tailscale").
                    # Gives `devtunnel funnel` a stable *.ts.net URL with no domain
                    # or DNS at all. NOT the `tailscale` *formula* — that runs its
                    # own tailscaled daemon and fights the menu-bar app.

# ---------- Language tooling — LSPs, linters, formatters, test runners ------
# Python — Astral stack (uv/ruff are Rust, blazing fast)
brew "uv"              # package/project manager (replaces pip, venv, poetry)
brew "ruff"            # linter + formatter (replaces black, flake8, isort)
# ty (Astral type checker, beta) — per-project: `uvx ty check`  or  `uv tool install ty`
# Rust — rustc/cargo/clippy/rustfmt/rust-analyzer come from rustup (see setup.sh)
brew "bacon"          # background compiler: watch/check/test loop
brew "cargo-nextest"  # faster, prettier test runner (bacon has a nextest job)
brew "sccache"        # shared compile cache across projects/branches (RUSTC_WRAPPER, see zshrc)
brew "cargo-binstall" # install cargo tools as prebuilt binaries (no source compile)
# Linker: Apple Silicon's default ld-prime is already fast — mold has no macOS
# support and sold is fragile, so no custom linker here.
# Go
brew "gopls"          # official Go language server
brew "golangci-lint"  # meta-linter (aggregates 50+ linters)
brew "delve"          # debugger (dlv) — understands goroutines/runtime
# air (live reload) — installed via `go install` in setup.sh
# JS / TypeScript / Next.js
brew "biome"          # Rust linter + formatter (ESLint + Prettier replacement)

# ---------- IDEs & editors ----------
# Daily drivers:
cask "gram"          # Zed fork without AI/telemetry
cask "cursor"        # AI-first code editor (VS Code fork)
# Compatibility targets — not daily drivers, installed to test tooling/extensions
# against what most devs actually run:
cask "visual-studio-code"  # VS Code — the baseline editor; test extensions/configs against stock
cask "zed"                 # upstream Zed — gram is a fork, so test against the real thing
cask "jetbrains-toolbox"   # installs/manages IntelliJ, PyCharm, GoLand, RustRover, WebStorm…
cask "sublime-text"        # still common enough to be worth a smoke test (subl CLI)
# Windsurf's cask was renamed "devin-desktop" after the Cognition acquisition — add if needed.
# Xcode is App Store-only (or the `xcodes` cask) — not brewed here.

# ---------- Apps ----------
cask "raycast"       # launcher / Spotlight replacement (free)
# Window management via Setapp (Swish / Rectangle Pro / Mosaic) instead of the free Rectangle cask
cask "setapp"        # your Setapp subscription manager
cask "google-chrome" # browser
cask "1password"     # password manager (already installed)
cask "1password-cli" # `op` CLI — secrets in scripts, git signing, ssh agent
cask "obsidian"      # local markdown notes
cask "stats"         # menu-bar system monitor
cask "slack"         # team chat
cask "discord"       # chat/communities

# Get from Setapp (already in your subscription — do NOT brew):
#   CleanShot X · Bartender · CleanMyMac · Gifox · Sip

# ---------- Security ----------
# cask "lulu"         # free outbound firewall (Objective-See)
cask "blockblock"     # alerts when anything installs persistence (launch agents/daemons)
cask "knockknock"     # audits what is already persistently installed — run after setup
cask "oversight"      # mic/camera access alerts
brew "age"            # modern file encryption (simple, keypair-based)
# NextDNS (DNS threat-feed filtering) is account-based — see README → Security.

# ---------- API & gRPC ----------
cask "bruno"        # REST + gRPC client, local & git-friendly (.bru files)
brew "protobuf"     # protoc compiler — required by prost-build / tonic Rust builds
brew "grpcurl"      # curl for gRPC
brew "grpcui"       # interactive web UI for gRPC
brew "buf"          # protobuf lint / generate / breaking-change detection

# ---------- AI tools ----------
# Claude Code (CLI) is NOT installed via brew — it ships its own self-updating
# native installer (curl -fsSL https://claude.ai/install.sh | bash), living in
# ~/.local/share/claude. A brew formula would fight its auto-updater. Don't add it.
cask "claude"       # Claude *Desktop* GUI (community cask)
cask "conductor"    # Conductor — run several Claude Code agents in parallel, one git worktree each
cask "chatgpt"      # ChatGPT desktop — NOTE: 566MB from a flaky CDN (persistent.oaistatic.com);
                    # if `brew bundle` fails here with curl(56), just re-run — it resumes.
cask "codex"        # OpenAI Codex CLI (official cask). No silent auto-update, but
                    # `codex update` (install-method-aware) or `brew upgrade` keeps it current.
brew "llm"          # Multi-provider LLM CLI wrapper (OpenAI built in; more via plugins)
brew "ollama"       # run LLMs locally

# ---------- Cloud / infra ----------
brew "kubectl"      # Kubernetes CLI
brew "k9s"          # Kubernetes TUI
brew "kubectx"      # fast context + namespace switching (installs kubectx & kubens)
brew "stern"        # multi-pod / multi-container log tailing
brew "helm"         # Kubernetes package manager
brew "awscli"      # AWS CLI
brew "flarectl"     # Cloudflare CLI (official, cloudflare-go). Needed to DELETE DNS
                    # records — cloudflared can only create them. Wants a
                    # Zone:DNS:Edit API token in CF_API_TOKEN.

# ---------- JS extras ----------
brew "pnpm"         # fast Node package manager
brew "bun"          # fast JS runtime / bundler / package manager

# Covered by your Setapp subscription (do NOT brew these):
#   TablePlus (DB GUI) · Proxyman (HTTP debug) · DevUtils (offline toolbox)
#   Dash (docs) · GitFox · Core Shell · ForkLift · GetAPI/Requestly · CodeRunner

# NOTE: Nix is NOT installed via Homebrew — see setup.sh (Determinate installer).
