# ~/.config/zsh/shortcuts.zsh — managed by ~/mac-setup
# Curated aliases & functions that complement the managed Zsh startup files.
# See ~/mac-setup/README.md for details. Reload with `reload`.

# ---------- Quick exits & basics ----------
alias x='exit'
alias c='clear'
alias coach='shell-coach'

# ---------- Directory navigation ----------
# bd <name>: jump up to the nearest ancestor whose name starts with <name>.
# Uses only Zsh path operations, so punctuation is literal and a miss cannot
# accidentally send an empty query to zoxide.
bd() {
  emulate -L zsh
  if (( $# != 1 )) || [[ -z "$1" ]]; then
    print -u2 -- 'usage: bd <ancestor-name>'
    return 2
  fi

  local query="$1" dir="${PWD:h}"
  while [[ "$dir" != / ]]; do
    if [[ "${dir:t}" == "$query"* ]]; then
      builtin cd -- "$dir"
      return
    fi
    dir="${dir:h}"
  done

  print -u2 -- "bd: no ancestor starts with '$query'"
  return 1
}

# mkcd <dir>: make a directory and cd into it
mkcd() {
  if (( $# != 1 )) || [[ -z "$1" ]]; then
    print -u2 -- 'usage: mkcd <directory>'
    return 2
  fi
  command mkdir -p -- "$1" && builtin cd -- "$1"
}

# Toggle back to the previous directory: `-` or the standard `cd -`.
alias -- -='builtin cd -'

# ---------- History ----------
alias h='history'
alias hg='history | rg'   # search shell history: hg <pattern>

# ---------- Extract any archive ----------
extract() {
  emulate -L zsh
  if (( $# != 1 )); then
    print -u2 -- 'usage: extract <archive>'
    return 2
  fi
  if [[ ! -f "$1" ]]; then
    print -u2 -- "extract: file not found: $1"
    return 1
  fi

  local archive="${1:A}"
  case "${archive:l}" in
    *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.zst|*.tar)
      command tar -xf "$archive" ;;
    *.gz)  command gunzip -- "$archive" ;;
    *.bz2) command bunzip2 -- "$archive" ;;
    *.xz)  command unxz -- "$archive" ;;
    *.zip) command unzip "$archive" ;;
    *)
      print -u2 -- "extract: unsupported format: $1"
      return 1 ;;
  esac
}

# ---------- Ports & processes ----------
alias ports='lsof -iTCP -sTCP:LISTEN -nP'  # what's listening

# Gracefully stop the listener on a TCP port. Use --force only when TERM fails.
killport() {
  emulate -L zsh
  local signal=TERM
  if [[ "${1:-}" == --force ]]; then
    signal=KILL
    shift
  fi
  if (( $# != 1 )) || [[ "$1" != <-> ]] || (( $1 < 1 || $1 > 65535 )); then
    print -u2 -- 'usage: killport [--force] <1-65535>'
    return 2
  fi

  local output
  output="$(command lsof -tiTCP:"$1" -sTCP:LISTEN 2>/dev/null)"
  if [[ -z "$output" ]]; then
    print -u2 -- "killport: nothing is listening on TCP port $1"
    return 1
  fi

  local -a pids
  pids=("${(@f)output}")
  builtin kill -"$signal" -- "${pids[@]}"
}

# ---------- Global aliases (pipe helpers) ----------
alias -g G='| rg'      # ... G pattern
alias -g L='| less'    # ... L
alias -g H='| head'    # ... H

# ---------- fzf helpers ----------
# fcd [root]: fuzzy-pick a subdirectory without traversing dependency/cache trees.
fcd() {
  emulate -L zsh
  local root="${1:-.}" selected
  if [[ ! -d "$root" ]]; then
    print -u2 -- "fcd: directory not found: $root"
    return 1
  fi

  selected="$(command fd --type d --hidden \
    --exclude .git --exclude node_modules --exclude target \
    -- . "$root" | fzf \
      --preview 'eza --tree --level=2 --color=always --icons -- {}')" || return
  [[ -n "$selected" ]] || return 1
  builtin cd -- "$selected"
}

# y: browse with Yazi, then leave the shell in Yazi's final directory on quit.
y() {
  local tmp cwd status
  tmp="$(mktemp -t 'yazi-cwd.XXXXXX')" || return
  command yazi "$@" --cwd-file="$tmp"
  status=$?
  IFS= read -r -d '' cwd < "$tmp"
  command rm -f -- "$tmp"
  [[ -n "$cwd" && "$cwd" != "$PWD" && -d "$cwd" ]] && builtin cd -- "$cwd"
  return "$status"
}
