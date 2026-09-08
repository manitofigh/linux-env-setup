# Linux development environment

Installs Mani's zsh/Oh My Zsh, tmux/TPM and AstroNvim configuration on Debian/Ubuntu, Fedora and Arch (including the listed derivatives). Run as your **normal login user**, not with `sudo`; the script uses sudo only for packages and changing that user's login shell.

```bash
git clone https://github.com/manitofigh/linux-env-setup.git
cd linux-env-setup
bash setup-env.sh --yes
```

Clone the whole repository: `bootstrap.lua` is needed alongside the shell script. Internet access and sudo package permissions are required for a full install. `--no-sudo` skips system packages and checks preinstalled dependencies; Neovim still installs into `~/.local`. `--skip-plugins` defers plugin/tool installation; `--no-chsh` retains your login shell. Without `--yes`, confirmation is requested once. Fedora/Debian package installation may need enabled standard repositories. Arch performs a full system upgrade to avoid partial upgrades.

## What gets installed

- Resolve Neovim's latest non-prerelease stable version using the GitHub releases API on each run. Try the distro package first and verify its actual version. If it lags, use the official x86_64/ARM64 archive with the GitHub asset SHA-256 digest. An unavailable/incompatible archive falls back to building the same stable tag with a staged install. No PPA or untrusted package repository is added. The binary is linked through `~/.local/bin`, and its version and runtime are checked. GitHub API rate limits/network failures stop setup rather than guessing a version.
- Clone/update [dotfiles](https://github.com/manitofigh/dotfiles) in `~/dev/dotfiles`; link the portable zsh entrypoint, burnt-orange theme and current tmux config.
- Clone Oh My Zsh and install `fzf-z`, `zsh-autosuggestions`, `zsh-syntax-highlighting`. Install zsh before attempting `chsh`; never launch a nested interactive shell during setup.
- Install TPM, tmux-sensible, tmux-resurrect, tmux-yank and tmux-continuum. No existing tmux server is started or changed during setup.
- Clone [AstroNvim config](https://github.com/manitofigh/astronvim) into `~/.config/nvim`, restore tracked plugin commits, install the current machine's Mason language tools plus rust-analyzer, and install configured Treesitter parsers. Installs Marp CLI into `~/.local`. Bounded headless runs report plugin/Mason/parser failures instead of claiming success.

## Existing machines and reruns

Conflicting files/directories are moved into unique adjacent `.backup.XXXXXXXX/original` paths before replacement. Existing managed Git repos must be clean, have the expected origin (HTTPS or SSH), and track the upstream default branch. Updates are fast-forward only. Local commits, edits or unexpected repositories stop setup for inspection; nothing resets or discards them. If the old installer modified OMZ's `themes/robbyrussell.zsh-theme`, preserve/commit that edit or move `~/.oh-my-zsh` aside before rerunning. Existing `.zshrc` is backed up; move the machine-specific portions you want into `~/.zshrc.local`.

Uses standard `~/.config/nvim` and `~/.zshrc` paths; custom XDG_CONFIG_HOME/ZDOTDIR is rejected. Shell customization of ZSH/DOTFILES_DIR should match these paths. The installer leaves Git identity untouched. Source builds require the compiler/build dependencies even under `--no-sudo`. Failed installs can be rerun after fixing the reported dependency or network problem; successfully installed files are retained.

## Additional integration requirements

Node.js **22+** is required for current npm plugin tools. If distro Node is older, the installer uses a dedicated nvm v0.40.7 checkout to install current Node LTS in user space, linking node/npm/npx through `~/.local/bin`. An existing personal nvm checkout is untouched. Full document workflows also require a TeX distribution with `latexmk` for Underleaf and a graphical browser for previews. OCaml development needs an opam environment with `ocaml-lsp-server`. Rust compilation needs cargo/rustc (installed by the package step). The 99 AI plugin needs `opencode` and provider authentication; credentials are never copied from another machine. A Nerd Font belongs in your terminal application (including on the SSH client), and clipboard integration depends on your desktop/SSH environment. These optional external integrations are not installed or authenticated automatically.

After setup, log out/in or run `zsh`, then open `tmux` and `nvim`. `:checkhealth` can identify host-specific integration issues. Plugin code is restored from the lockfile, but external language-server packages use current Mason versions.

## Validation

Reviewed statically on macOS: shell/Lua syntax, package mappings, ownership, backups, release/version/integrity handling and bootstrap control flow. The Linux installer has **not** been executed on Linux; distro package availability and full end-to-end setup remain unverified.
