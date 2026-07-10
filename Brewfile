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

# ---------- Git ----------
brew "git"
brew "gh"           # GitHub CLI
brew "lazygit"      # git TUI
brew "git-delta"    # better git diffs

# ---------- Dev environment ----------
cask "orbstack"     # Docker / Linux VMs (light Docker Desktop replacement)
brew "mise"         # runtime/version manager (node, python, go, rust)
brew "neovim"       # editor
brew "direnv"       # per-directory environment variables

# ---------- Language tooling — LSPs, linters, formatters, test runners ------
# Python — Astral stack (uv/ruff are Rust, blazing fast)
brew "uv"              # package/project manager (replaces pip, venv, poetry)
brew "ruff"            # linter + formatter (replaces black, flake8, isort)
# ty (Astral type checker, beta) — per-project: `uvx ty check`  or  `uv tool install ty`
# Rust — rustc/cargo/clippy/rustfmt/rust-analyzer come from rustup (see setup.sh)
brew "bacon"          # background compiler: watch/check/test loop
brew "cargo-nextest"  # faster, prettier test runner (bacon has a nextest job)
# Go
brew "gopls"          # official Go language server
brew "golangci-lint"  # meta-linter (aggregates 50+ linters)
brew "delve"          # debugger (dlv) — understands goroutines/runtime
# air (live reload) — installed via `go install` in setup.sh
# JS / TypeScript / Next.js
brew "biome"          # Rust linter + formatter (ESLint + Prettier replacement)

# ---------- Apps ----------
cask "gram"          # Zed fork without AI/telemetry
cask "cursor"        # AI-first code editor (VS Code fork)
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
cask "little-snitch"  # outbound firewall: per-app/per-domain rules + alert mode (paid — the good one)
# cask "lulu"         # free outbound firewall (Objective-See) — alternative; do NOT run both
cask "blockblock"     # alerts when anything installs persistence (launch agents/daemons)
cask "knockknock"     # audits what is already persistently installed — run after setup
cask "oversight"      # mic/camera access alerts
# NextDNS (DNS threat-feed filtering) is account-based — see README → Security.

# ---------- API & gRPC ----------
cask "bruno"        # REST + gRPC client, local & git-friendly (.bru files)
brew "grpcurl"      # curl for gRPC
brew "grpcui"       # interactive web UI for gRPC
brew "buf"          # protobuf lint / generate / breaking-change detection

# ---------- AI tools ----------
# cask "claude"     # Claude Desktop — CDN download flaky in this env; installed separately below
cask "chatgpt"      # ChatGPT desktop
cask "codex"        # OpenAI Codex CLI
brew "ollama"       # run LLMs locally

# ---------- Cloud / infra ----------
brew "kubectl"      # Kubernetes CLI
brew "k9s"          # Kubernetes TUI
brew "helm"         # Kubernetes package manager
brew "awscli"       # AWS CLI

# ---------- JS extras ----------
brew "pnpm"         # fast Node package manager
brew "bun"          # fast JS runtime / bundler / package manager

# Covered by your Setapp subscription (do NOT brew these):
#   TablePlus (DB GUI) · Proxyman (HTTP debug) · DevUtils (offline toolbox)
#   Dash (docs) · GitFox · Core Shell · ForkLift · GetAPI/Requestly · CodeRunner

# NOTE: Nix is NOT installed via Homebrew — see setup.sh (Determinate installer).
