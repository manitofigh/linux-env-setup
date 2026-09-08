#!/usr/bin/env bash
# Run as your normal login user. System packages alone use sudo.
set -Eeuo pipefail

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage: bash setup-env.sh [--yes] [--no-sudo] [--skip-plugins] [--no-chsh]
Supports Debian/Ubuntu, Fedora and Arch Linux. Run as your normal user.
  --yes           Start without confirmation (package installs are unattended)
  --no-sudo       Skip system packages; require dependencies already installed
  --skip-plugins  Configure files but defer Neovim plugin/tool installation
  --no-chsh       Keep the current login shell
USAGE
}
backup() {
  if [[ -e $1 || -L $1 ]]; then
    local saved
    saved="$(mktemp -d "${1}.backup.XXXXXXXX")"
    mv -- "$1" "$saved/original"
    log "Preserved $1 at $saved/original"
  fi
}
link_config() {
  [[ -L $2 && $(readlink "$2") == "$1" ]] && return 0
  backup "$2"
  mkdir -p "$(dirname "$2")"
  ln -s -- "$1" "$2"
}
# Never silently reset local work or pull from an unexpected origin.
sync_repo() {
  local url=$1 dest=$2
  if [[ -d $dest/.git ]]; then
    [[ $(git -C "$dest" remote get-url origin | sed -e 's|^git@github.com:|https://github.com/|' -e 's|\.git$||') == "${url%.git}" ]] || die "Unexpected origin in $dest; inspect it before rerunning."
    [[ -z $(git -C "$dest" status --porcelain) ]] || die "Local changes in $dest; commit/stash them before rerunning."
    git -C "$dest" symbolic-ref -q HEAD >/dev/null || die "Detached checkout: $dest"
    git -C "$dest" fetch --prune origin
    git -C "$dest" remote set-head origin --auto
    [[ $(git -C "$dest" rev-parse --abbrev-ref '@{upstream}') == "$(git -C "$dest" symbolic-ref --short refs/remotes/origin/HEAD)" ]] || die "Checkout in $dest must track origin's default branch."
    [[ $(git -C "$dest" rev-list --count '@{upstream}..HEAD') == 0 ]] || die "Unpushed/local commits in $dest; inspect before rerunning."
    git -C "$dest" merge --ff-only '@{upstream}'
  else
    backup "$dest"
    mkdir -p "$(dirname "$dest")"
    git clone -- "$url" "$dest"
  fi
}
install_packages() {
  local common=(ca-certificates curl git tmux zsh unzip tar gzip xz-utils ripgrep fzf tree cmake make ninja-build gettext pkg-config bison flex gdb strace ccache autoconf automake libtool)
  case $DISTRO in
    apt)
      "${SUDO[@]}" apt-get update
      "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "${common[@]}" build-essential python3 python3-pip python3-venv nodejs npm fd-find xclip wl-clipboard clangd libncurses-dev libssl-dev libelf-dev libtool-bin util-linux passwd cargo rustc
      ;;
    dnf)
      "${SUDO[@]}" dnf install -y ca-certificates curl git tmux zsh unzip tar gzip xz ripgrep fzf tree cmake make ninja-build gettext pkgconf-pkg-config bison flex gdb strace ccache autoconf automake libtool gcc gcc-c++ python3 python3-pip nodejs npm fd-find xclip wl-clipboard clang-tools-extra ncurses-devel openssl-devel elfutils-libelf-devel util-linux-user cargo rust
      ;;
    pacman)
      "${SUDO[@]}" pacman -Syu --needed --noconfirm ca-certificates curl git tmux zsh unzip tar gzip xz ripgrep fzf tree cmake ninja gettext pkgconf base-devel gdb strace ccache python python-pip nodejs npm fd xclip wl-clipboard clang ncurses openssl libelf util-linux rust
      ;;
  esac
}
nvim_version() { "$1" --version 2>/dev/null | sed -n '1s/^NVIM v\([0-9]*\.[0-9]*\.[0-9]*\)$/\1/p'; }
install_neovim() {
  local release="$WORK/release.json" version asset digest url archive binary='' prefix
  curl -fLsS --retry 3 https://api.github.com/repos/neovim/neovim/releases/latest -o "$release"
  version=$(python3 - "$release" <<'PY'
import json,re,sys
r=json.load(open(sys.argv[1])); tag=r['tag_name']
assert not r.get('prerelease') and not r.get('draft') and re.fullmatch(r'v\d+\.\d+\.\d+',tag), 'Invalid stable release'
print(tag[1:])
PY
)
  log "Latest upstream Neovim stable: $version"
  if command -v nvim >/dev/null && [[ $(nvim_version "$(command -v nvim)") == "$version" ]]; then return; fi
  if ! $NO_SUDO; then
    case $DISTRO in
      apt) "${SUDO[@]}" apt-get install -y neovim || log 'Distro Neovim unavailable; using upstream fallback.' ;;
      dnf) "${SUDO[@]}" dnf install -y neovim || log 'Distro Neovim unavailable; using upstream fallback.' ;;
      pacman) "${SUDO[@]}" pacman -S --needed --noconfirm neovim || log 'Distro Neovim unavailable; using upstream fallback.' ;;
    esac
    if [[ -x /usr/bin/nvim && $(nvim_version /usr/bin/nvim) == "$version" ]]; then
      link_config /usr/bin/nvim "$HOME/.local/bin/nvim"
      return
    fi
  fi
  case $(uname -m) in
    x86_64) asset=nvim-linux-x86_64 ;;
    aarch64|arm64) asset=nvim-linux-arm64 ;;
    *) asset='' ;;
  esac
  prefix="$HOME/.local/opt/nvim-$version"
  if [[ -n $asset ]]; then
    read -r url digest < <(python3 - "$release" "$asset.tar.gz" <<'PY'
import json,sys
for a in json.load(open(sys.argv[1]))['assets']:
    if a['name']==sys.argv[2]: print(a['browser_download_url'],a.get('digest') or ''); break
PY
) || true
    if [[ ${url:-} == https://github.com/neovim/neovim/releases/download/* && ${digest:-} =~ ^sha256:[a-f0-9]{64}$ ]]; then
      archive="$WORK/nvim.tar.gz"
      if curl -fLsS --retry 3 "$url" -o "$archive" &&
        printf '%s  %s\n' "${digest#sha256:}" "$archive" | sha256sum -c - &&
        tar -xzf "$archive" -C "$WORK" &&
        [[ $(nvim_version "$WORK/$asset/bin/nvim") == "$version" ]]; then
        binary="$WORK/$asset"
      fi
    fi
  fi
  if [[ -z $binary ]]; then
    log 'No compatible verified binary; building the stable tag (may take several minutes).'
    git clone --depth 1 --branch "v$version" https://github.com/neovim/neovim.git "$WORK/source"
    make -C "$WORK/source" CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$prefix" -j2
    DESTDIR="$WORK/stage" make -C "$WORK/source" install
    binary="$WORK/stage$prefix"
    [[ $(nvim_version "$binary/bin/nvim") == "$version" ]] || die 'Built Neovim failed version check.'
  fi
  mkdir -p "$HOME/.local/opt"
  backup "$prefix"
  mv -- "$binary" "$prefix"
  link_config "$prefix/bin/nvim" "$HOME/.local/bin/nvim"
  [[ $(nvim_version "$HOME/.local/bin/nvim") == "$version" ]] || die 'Installed Neovim failed validation.'
}
setup_node() {
  if node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)'; then return; fi
  log 'Distro Node is too old; installing current Node LTS with nvm in user space.'
  local manager="$HOME/.local/share/linux-env-setup/nvm" node_path tool
  # A dedicated pinned manager avoids changing an existing personal nvm checkout.
  if [[ ! -d $manager ]]; then
    mkdir -p "$(dirname "$manager")"
    git clone --depth 1 --branch v0.40.7 https://github.com/nvm-sh/nvm.git "$manager"
  fi
  [[ -r $manager/nvm.sh ]] || die "Incomplete nvm checkout: $manager"
  (
    set +u
    export NVM_DIR="$manager"
    # shellcheck disable=SC1091
    source "$manager/nvm.sh"
    nvm install --lts
    nvm which current > "$WORK/node-path"
  )
  node_path=$(cat "$WORK/node-path")
  [[ -x $node_path ]] || die 'nvm did not install Node.'
  for tool in node npm npx; do
    link_config "$(dirname "$node_path")/$tool" "$HOME/.local/bin/$tool"
  done
  hash -r
  node -e 'if (Number(process.versions.node.split(".")[0]) < 22) process.exit(1)'
}
setup_configs() {
  sync_repo https://github.com/manitofigh/dotfiles.git "$HOME/dev/dotfiles"
  sync_repo https://github.com/manitofigh/astronvim.git "$HOME/.config/nvim"
  sync_repo https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  local custom="$HOME/.oh-my-zsh/custom"
  sync_repo https://github.com/zsh-users/zsh-autosuggestions.git "$custom/plugins/zsh-autosuggestions"
  sync_repo https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom/plugins/zsh-syntax-highlighting"
  sync_repo https://github.com/andrewferrier/fzf-z.git "$custom/plugins/fzf-z"
  mkdir -p "$custom/themes"
  link_config "$HOME/dev/dotfiles/zsh/burnt-orange.zsh-theme" "$custom/themes/burnt-orange.zsh-theme"
  link_config "$HOME/dev/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
  link_config "$HOME/dev/dotfiles/tmux.conf" "$HOME/.tmux.conf"
  local plugin
  for plugin in tpm tmux-sensible tmux-resurrect tmux-yank tmux-continuum; do
    sync_repo "https://github.com/tmux-plugins/$plugin.git" "$HOME/.tmux/plugins/$plugin"
  done
  # TPM discovers these standard directories when tmux starts; no live server needed.
  zsh -n "$HOME/.zshrc"
}
setup_shell() {
  $NO_CHSH && return 0
  local shell_path current
  shell_path=$(command -v zsh)
  current=$(getent passwd "$(id -un)" | cut -d: -f7)
  [[ $current == "$shell_path" ]] && return 0
  if ! grep -Fxq "$shell_path" /etc/shells; then
    log "Login shell unchanged: $shell_path is not registered in /etc/shells."
  elif $NO_SUDO; then
    log "To change your login shell, run: chsh -s $shell_path"
  elif ! "${SUDO[@]}" chsh -s "$shell_path" "$(id -un)"; then
    log "chsh was refused (common with containers/managed accounts). Run zsh manually."
  fi
}
main() {
  local yes=false
  NO_SUDO=false NO_CHSH=false SKIP_PLUGINS=false
  while (($#)); do
    case $1 in
      -h|--help) usage; return ;;
      --yes|-y) yes=true ;;
      --no-sudo) NO_SUDO=true ;;
      --no-chsh) NO_CHSH=true ;;
      --skip-plugins) SKIP_PLUGINS=true ;;
      *) usage; die "Unknown option: $1" ;;
    esac
    shift
  done
  [[ $(uname -s) == Linux ]] || die 'This installer is for Linux only.'
  [[ $EUID -ne 0 ]] || die 'Run as your normal login user, without sudo. The script elevates only system package commands.'
  [[ -r /etc/os-release ]] || die 'Cannot identify distribution.'
  # shellcheck disable=SC1091
  source /etc/os-release
  case ${ID:-} in
    ubuntu|debian|linuxmint|pop) DISTRO=apt ;;
    fedora) DISTRO=dnf ;;
    arch|endeavouros|manjaro) DISTRO=pacman ;;
    *) die "Unsupported distribution: ${ID:-unknown}. Use Debian/Ubuntu, Fedora or Arch." ;;
  esac
  [[ ${XDG_CONFIG_HOME:-$HOME/.config} == "$HOME/.config" && ${ZDOTDIR:-$HOME} == "$HOME" ]] || die 'Custom XDG_CONFIG_HOME/ZDOTDIR is not supported; use the standard home paths.'
  if ! $yes; then
    local answer
    read -r -p 'Install development packages and configure zsh, tmux and AstroNvim? [y/N] ' answer || die 'No input; use --yes for unattended setup.'
    [[ $answer == y || $answer == Y ]] || return 0
  fi
  SUDO=()
  if ! $NO_SUDO; then
    command -v sudo >/dev/null || die 'sudo is required, or preinstall dependencies and use --no-sudo.'
    SUDO=(sudo)
    sudo -v
    install_packages
  fi
  local dep
  for dep in curl git python3 zsh tmux tar sha256sum timeout make cmake gcc g++ unzip rg fzf tree node npm; do
    command -v "$dep" >/dev/null || die "Missing dependency: $dep. Install it before using --no-sudo."
  done
  mkdir -p "$HOME/.local/bin" "$HOME/scripts"
  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then link_config "$(command -v fdfind)" "$HOME/.local/bin/fd"; fi
  WORK=$(mktemp -d)
  trap 'if [[ -f "$WORK/lazy-lock.json" ]]; then cp -- "$WORK/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"; fi; rm -rf -- "$WORK"' EXIT
  install_neovim
  nvim --headless -u NONE '+lua assert(vim.fn.isdirectory(vim.env.VIMRUNTIME) == 1, "Missing Neovim runtime")' +qa
  setup_configs
  if ! $SKIP_PLUGINS; then
    setup_node
    npm install --global --prefix "$HOME/.local" @marp-team/marp-cli
    # Lazy rewrites this tracked file; retain the source snapshot on success/failure.
    cp -- "$HOME/.config/nvim/lazy-lock.json" "$WORK/lazy-lock.json"
    export SETUP_BOOTSTRAP="$SCRIPT_DIR/bootstrap.lua"
    SETUP_STAGE=plugins timeout 1200 nvim --headless '+lua dofile(vim.env.SETUP_BOOTSTRAP)'
    SETUP_STAGE=tools timeout 1800 nvim --headless '+lua dofile(vim.env.SETUP_BOOTSTRAP)'
  fi
  setup_shell
  log 'Setup finished. Log out/in for the new login shell, or run zsh. See README for optional language tools and credentials.'
}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
