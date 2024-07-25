#!/bin/bash

# Setup script for configuring a Linux development environment
# Supports Ubuntu, Fedora, and Arch Linux distributions
# Allows running with or without sudo permissions
# Installs necessary packages for kernel development, zsh, Oh My Zsh, and Neovim

# Define color codes for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to display formatted console logs
log_msg() {
	local msg="$1"
	local len=$((${#msg} + 4))
	local border=$(printf "%${len}s" | tr ' ' '-')
	printf "\n+%s+\n|  %s  |\n+%s+\n" "${border}" "${msg}" "${border}"
	sleep 2
}

# Function to set up zsh and Oh My Zsh
setup_zsh() {
	log_msg "Setting up zsh and Oh My Zsh"

	$sudo_cmd chsh -s "$(command -v zsh)" "$(whoami)"
	ZSH="$HOME/.oh-my-zsh" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

	log_msg "Configuring Oh My Zsh theme"

	cat <<-'EOF' > "$HOME/.oh-my-zsh/themes/robbyrussell.zsh-theme"
	PROMPT="%{$fg[green]%}%n%{$fg_bold[white]%}@%{$fg_bold[green]%}%m %(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{💀%} ) %{$fg[cyan]%}%c%{$reset_color%}"
	PROMPT+=' $(git_prompt_info)'

	ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
	ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
	ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
	ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
	EOF
}

# Function to set up scripts directory and add to PATH
setup_scripts_dir() {
	log_msg "Setting up scripts directory"

	mkdir -p "$HOME/scripts"
	echo 'export PATH="$HOME/scripts:$PATH"' >> ~/.zshrc
}

# build nvim from source
# package managers install older versions of nvim which don't support some major plugins
install_neovim() {
	log_msg "Installing Neovim"

	wget https://github.com/neovim/neovim/archive/refs/tags/v0.10.0.tar.gz
	tar xzvf v0.10.0.tar.gz
	cd neovim-0.10.0 || exit 1
	make CMAKE_BUILD_TYPE=Release
	$sudo_cmd make install
	cd ..
	rm -rf neovim-0.10.0 v0.10.0.tar.gz
}

setup_git() {
	log_msg "Setting up git configuration"

	git config --global user.name "Mani Tofigh"
	git config --global user.email "manitofigh@protonmail.com"
  if [[ ! -d ~/.config ]]; then
    mkdir ~/.config
  fi
	git clone https://github.com/manitofigh/nvim.git ~/.config/nvim
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

# Parse command-line arguments
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
		echo -e "${RED}Script must be run with sudo or with the --no-sudo flag.${NC}"
		exit 1
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

# Install curl and git first
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

packages=(
	tmux ltrace python3 python3-pip vim gcc g++ make gdb strace
	build-essential libncurses-dev bison flex libssl-dev libelf-dev
	fakeroot ccache libncurses-dev libncurses5-dev zsh gettext
	libtool libtool-bin autoconf automake cmake pkg-config unzip
)

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

setup_zsh
setup_scripts_dir
install_neovim
setup_git

source ~/.zshrc

log_msg "Setup complete!"
echo "Please restart your terminal or run 'source ~/.zshrc' to apply the changes."
