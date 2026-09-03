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
brew "agg"          # asciinema .cast → GIF converter
brew "vhs"          # scripted terminal GIFs from a .tape file (Charm) — reproducible demos

# ---------- GNU gap fillers (macOS ships a BSD userland) ----------
# macOS has NO `timeout`, `tac`, `shuf`, `nproc` or `numfmt` at all — scripts and
# agents that reach for `timeout 30 cmd` just fail with "command not found".
brew "coreutils"    # Installing it is the whole fix: coreutils g-prefixes ONLY the
                    # names macOS also ships (gsed, gdate, gls), and puts the ones
                    # macOS lacks straight into bin unprefixed — so `timeout`, `tac`,
                    # `shuf`, `nproc`, `numfmt` just work, no PATH surgery.
                    # Do NOT add libexec/gnubin to PATH (the caveat's suggestion):
                    # that swaps sed/date/ls/cp/stat machine-wide, and installers,
                    # brew formulae and vendor scripts assume BSD flags.
brew "moreutils"    # sponge (write back to the file you're reading — `jq . f | sponge f`),
                    # ts (timestamp each line of a stream), chronic (run quietly,
                    # print only if it fails), vipe, errno, ifne.
                    # Conflicts with the `parallel` formula, so no GNU parallel here —
                    # watchexec + hyperfine + `xargs -P` already cover that ground.
brew "gawk"         # GNU awk — macOS ships the one-true-awk (no gensub, asorti, regex RS)
brew "watch"        # macOS has no `watch` — re-run a command on an interval
brew "pv"           # pipe viewer — progress/throughput bar for any pipe

# ---------- macOS automation ----------
brew "mas"                # Mac App Store CLI. This is how Xcode gets scripted:
                          # `mas install 497799835` — see the Xcode note below.
brew "dockutil"           # add/remove/reorder Dock items from a script (macos-defaults.sh)
brew "terminal-notifier"  # Notification Center from a shell script — `setup.sh; terminal-notifier -message done`
brew "defaultbrowser"     # set the default browser non-interactively

# ---------- Data from the shell ----------
brew "duckdb"       # SQL straight over CSV/Parquet/JSON, no server, no import step:
                    # `duckdb -c "select * from 'x.csv' where …"`
brew "jless"        # JSON/YAML TUI viewer — jq is for scripting, jless is for spelunking
brew "sqlite-utils" # inspect/transform SQLite from the CLI (and CSV/JSON -> SQLite)

# ---------- Local web & network dev ----------
brew "mkcert"       # locally-trusted HTTPS certs for localhost — the offline
                    # counterpart to cloudflared/devtunnel when you need real TLS
brew "oha"          # HTTP load testing with a live TUI (Rust) — `oha -z 10s http://localhost:3000`
brew "websocat"     # curl for WebSockets — connect, send frames, pipe stdin

# ---------- Media & documents ----------
brew "ffmpeg"       # the universal audio/video converter. Big install (~fifty deps).
brew "imagemagick"  # the universal image converter (`magick in.png out.webp`)
brew "poppler"      # pdftotext / pdfimages / pdfinfo — makes PDFs greppable (and agent-readable)
brew "pandoc"       # convert between markdown, docx, HTML, LaTeX, PDF…

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
# Shell — this repo is itself ~2k lines of bash/zsh; lint it like real code
brew "shellcheck"     # THE shell linter — catches unquoted expansions, bad [[ ]], set -e traps
brew "shfmt"          # shell formatter (also a `bash-language-server` companion)

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
# Xcode is App Store-only (or the `xcodes` cask) — not brewed here. With `mas`
# installed (see macOS automation) it is at least scriptable: `mas install 497799835`.

# ---------- Apps ----------
cask "raycast"       # launcher / Spotlight replacement (free)
# Window management via Setapp (Swish / Rectangle Pro / Mosaic) instead of the free Rectangle cask
cask "setapp"        # your Setapp subscription manager
cask "google-chrome" # browser
cask "1password"     # password manager (already installed)
cask "1password-cli" # `op` CLI — secrets in scripts, git signing, ssh agent
cask "obsidian"      # local markdown notes
cask "notion"        # workspace / docs (cloud counterpart to obsidian's local notes)
cask "notion-calendar" # calendar client (the app formerly known as Cron)
cask "linear"        # issue tracker desktop app (schpet/tap/linear above is the CLI)
cask "stats"         # menu-bar system monitor
cask "slack"         # team chat
cask "discord"       # chat/communities
cask "spotify"       # music

# Get from Setapp (already in your subscription — do NOT brew):
#   CleanShot X · Bartender · CleanMyMac · Gifox · Sip
# The installed set is tracked in ./Setappfile — restore it with `setapp-sync install`.

# ---------- Security ----------
# cask "lulu"         # free outbound firewall (Objective-See)
cask "blockblock"     # alerts when anything installs persistence (launch agents/daemons)
cask "knockknock"     # audits what is already persistently installed — run after setup
cask "oversight"      # mic/camera access alerts
brew "age"            # modern file encryption (simple, keypair-based)
brew "gitleaks"       # scan history + working tree for committed secrets.
                      # This repo is public — run `gitleaks git .` before pushing.
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
brew "gemini-cli"   # Google's agent CLI — third seat next to Claude Code and Codex
brew "notion-mcp-server" # official Notion MCP server — lets agents read/write the
                    # workspace. Needs an integration token (notion.so/profile/integrations)
                    # in NOTION_TOKEN + registration via `claude mcp add`; installing
                    # the formula alone does nothing.
brew "ccusage"      # prices your agent token usage at API rates: what the subscription
                    # "would have cost" in cash. Reads local JSONL logs for Claude Code,
                    # Codex, Gemini CLI, Copilot, OpenCode, Goose… `ccusage daily|monthly
                    # |session`, `--json` for scripting. Nothing leaves the machine.

# ---------- Local inference ----------
# Ollama 0.19+ (Mar 2026) runs a native MLX runner on Apple Silicon, so the formula
# below is already on Apple's fast path — no separate "Mac edition" to install.
brew "ollama"       # run LLMs locally (CLI + server, OpenAI-compatible API)
cask "ollama-app"   # the official Ollama GUI on top of that server
brew "mlx-lm"       # Apple MLX inference CLI — Apple Silicon only, ~20-50% faster
                    # than llama.cpp on the same model/quant. `mlx_lm.generate|server`
brew "llama.cpp"    # reference engine + GGUF tooling (quantize, convert, llama-bench)
cask "lm-studio"    # GUI model browser + headless server (llmster), MLX engine
# jan (offline chat app, native MLX since 0.7.7) is the FOSS alternative to LM Studio.
# msty/msty-studio: discontinued upstream, cask disabled 2027-01-02 — do NOT add.

# ---------- Cloud / infra ----------
brew "kubectl"      # Kubernetes CLI
brew "k9s"          # Kubernetes TUI
brew "kubectx"      # fast context + namespace switching (installs kubectx & kubens)
brew "stern"        # multi-pod / multi-container log tailing
brew "helm"         # Kubernetes package manager
brew "kustomize"    # manifest overlays (patch base YAML per env without templating)
brew "kind"         # local k8s cluster in Docker — test manifests before EKS/GKE
brew "f1bonacc1/tap/process-compose"  # docker-compose-style orchestrator for local (non-container) processes
brew "awscli"      # AWS CLI
brew "eksctl"       # create/manage EKS clusters (awscli only talks to existing ones)
brew "aws-vault"    # stores AWS creds in the macOS keychain, injects short-lived
                    # creds per-shell instead of long-lived keys in ~/.aws/credentials
cask "session-manager-plugin" # needed for `aws ssm start-session` — bastion-less
                    # shell into EC2/ECS without opening SSH
cask "gcloud-cli"   # Google Cloud CLI — `gcloud`, `gsutil`, `bq` (was google-cloud-sdk)
                    # GKE auth needs a separate component: `gcloud components install
                    # gke-gcloud-auth-plugin` (not a brew package). EKS auth is native to awscli.
brew "azure-cli"    # Azure CLI — `az`. Bicep (Azure's IaC DSL) isn't a brew package either:
                    # run `az bicep install` once az is set up.
brew "kubelogin"    # AKS auth plugin — kubectl needs this for Azure AD/Entra ID login,
                    # same role gke-gcloud-auth-plugin plays for GKE.
brew "azcopy"       # fast Azure Blob/Files transfer CLI (az storage commands are slow for bulk data)
brew "sops"         # encrypt secrets in git (used with kustomize/helm in GitOps flows)
brew "opentofu"     # IaC for provisioning the AWS/GCP infra itself (FOSS terraform fork —
                    # terraform itself was pulled from homebrew-core in 2023 over its BUSL
                    # license change; use `hashicorp/tap/terraform` instead if you need upstream)
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
