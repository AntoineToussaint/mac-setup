# ~/.config/zsh/shortcuts.zsh — managed by ~/mac-setup
# Curated aliases & functions that complement the tools set up in zshrc.
# See ~/mac-setup/README.md for details. Reload with `reload`.

# ---------- Quick exits & basics ----------
alias x='exit'
alias c='clear'

# ---------- Directory navigation ----------
# bd <name>: jump UP to an ancestor directory whose name matches <name>
bd() { cd "$(pwd | sed "s|\(.*/$1[^/]*/\).*|\1|")"; }

# mkcd <dir>: make a directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# toggle back to the previous directory
alias -- -='cd -'

# ---------- History ----------
alias h='history'
alias hg='history | rg'   # search shell history: hg <pattern>

# ---------- Extract any archive ----------
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

# ---------- Ports & processes ----------
alias ports='lsof -iTCP -sTCP:LISTEN -nP'          # what's listening
killport() { lsof -ti tcp:"$1" | xargs kill -9; }  # killport 3000

# ---------- Global aliases (pipe helpers) ----------
alias -g G='| rg'      # ... G pattern
alias -g L='| less'    # ... L
alias -g H='| head'    # ... H

# ---------- fzf helpers ----------
# fcd: fuzzy-pick a subdirectory and cd into it
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)"; }
