#!/bin/bash

# Setup script for configuring a Linux development environment
# Supports Ubuntu, Fedora, and Arch Linux distributions
# Allows running with or without sudo permissions
# Interactively installs packages and tools for kernel development,
# zsh, Oh My Zsh, and Neovim based on user preferences
# Author: Mani Tofigh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_msg() {
    local msg="$1"
    local len=$((${#msg} + 4))
    local border=$(printf "%${len}s" | tr ' ' '-')
    printf "\n+%s+\n|  %s  |\n+%s+\n" "${border}" "${msg}" "${border}"
    sleep 1
}

confirm() {
    read -p "$1 (y/n): " choice
    case "$choice" in
        y|Y ) return 0 ;;
        n|N ) return 1 ;;
        * ) echo "Invalid input. Please enter 'y' or 'n'."; confirm "$1" ;;
    esac
}

setup_zsh() {
    $sudo_cmd chsh -s "$(command -v zsh)" "$(whoami)"
}

setup_scripts_dir() {
    mkdir -p "$HOME/scripts"
    echo 'export PATH="$HOME/scripts:$PATH"' >> ~/.zshrc
}

install_neovim() {
    wget https://github.com/neovim/neovim/archive/refs/tags/v0.10.0.tar.gz
    tar xzvf v0.10.0.tar.gz
    cd neovim-0.10.0 || exit 1
    make CMAKE_BUILD_TYPE=Release
    $sudo_cmd make install
    cd ..
    rm -rf neovim-0.10.0 v0.10.0.tar.gz
}

setup_git() {
    git config --global user.name "Mani Tofigh"
    git config --global user.email "manitofigh@protonmail.com"
}

setup_nvim_config() {
    if [[ ! -d ~/.config ]]; then
        mkdir ~/.config
    fi
    git clone https://github.com/manitofigh/nvim.git ~/.config/nvim
}

setup_oh_my_zsh() {
    ZSH="$HOME/.oh-my-zsh" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    cat <<'EOF' > "$HOME/.oh-my-zsh/themes/robbyrussell.zsh-theme"
PROMPT="%{$fg[green]%}%n%{$fg_bold[white]%}@%{$fg_bold[green]%}%m %(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{💀%} ) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
EOF
}

usage() {
    echo "Usage: $0 [-h] [--no-sudo]"
    echo
    echo "Setup script for configuring a Linux development environment"
    echo
    echo "Options:"
    echo "  -h, --help    Display this help message and exit"
    echo "  --no-sudo     Run the script without using sudo"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --no-sudo)
            no_sudo=true
            shift
            ;;
        *)
            echo "Invalid argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ $EUID -eq 0 ]]; then
    if [[ $no_sudo ]]; then
        echo "Script is running with sudo, but --no-sudo was specified."
        echo "Please run the script without sudo or remove the --no-sudo flag."
        exit 1
    fi
    sudo_cmd=""
else
    if [[ $no_sudo ]]; then
        sudo_cmd=""
        echo -e "${YELLOW}Running script without sudo. Some features may not work.${NC}"
    else
        sudo_cmd="sudo"
    fi
fi

echo "Select your Linux distribution:"
echo "1) Ubuntu"
echo "2) Fedora"
echo "3) Arch"
read -r choice

case $choice in
    1)
        distro="ubuntu"
        pkg_manager="apt"
        ;;
    2)
        distro="fedora"
        pkg_manager="dnf"
        ;;
    3)
        distro="arch"
        pkg_manager="pacman"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo -e "${GREEN}Setting up development environment for $distro${NC}"

if confirm "Install curl and git?"; then
    log_msg "Installing curl and git"
    case $pkg_manager in
        "apt")
            $sudo_cmd apt update
            $sudo_cmd apt install -y curl git
            ;;
        "dnf")
            $sudo_cmd dnf install -y curl git
            ;;
        "pacman")
            $sudo_cmd pacman -Syu --noconfirm curl git
            ;;
    esac
fi

packages=(
    tmux ltrace python3 python3-pip vim gcc g++ make gdb strace
    build-essential libncurses-dev bison flex libssl-dev libelf-dev
    fakeroot ccache libncurses-dev libncurses5-dev zsh gettext
    libtool libtool-bin autoconf automake cmake pkg-config unzip
)

if confirm "Install development packages?"; then
    log_msg "Installing packages"
    case $pkg_manager in
        "apt")
            $sudo_cmd apt install -y "${packages[@]}"
            ;;
        "dnf")
            $sudo_cmd dnf install -y "${packages[@]}"
            ;;
        "pacman")
            $sudo_cmd pacman -Syu --noconfirm "${packages[@]}"
            ;;
    esac
fi

if confirm "Set up zsh?"; then
    log_msg "Setting up zsh"
    setup_zsh
fi

if confirm "Set up scripts directory?"; then
    log_msg "Setting up scripts directory"
    setup_scripts_dir
fi

if confirm "Install Neovim from source?"; then
    log_msg "Installing Neovim"
    install_neovim

    if confirm "Set up Neovim based on Mani Tofigh's configuration?"; then
        log_msg "Setting up Neovim configuration"
        setup_nvim_config
    fi
fi

if confirm "Set up git configuration?"; then
    log_msg "Setting up git configuration"
    setup_git
fi

if confirm "Install Oh My Zsh?"; then
    log_msg "Installing Oh My Zsh"
    setup_oh_my_zsh
fi

log_msg "Setup complete!"
echo "Please restart your terminal or run 'source ~/.zshrc' to apply the changes."
