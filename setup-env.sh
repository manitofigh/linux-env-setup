#!/bin/bash

# Function to display usage
show_usage() {
    echo "Usage: $0 [-h] [--no-sudo]"
    echo "  -h         Show this help message"
    echo "  --no-sudo  Run without sudo (some installations may fail)"
}

# Function to display log messages
log_message() {
    local message="$1"
    local width=50
    local padding=$(( (width - ${#message}) / 2 ))
    printf "+%${width}s+\n" | tr ' ' '-'
    printf "|%*s%s%*s|\n" $padding "" "$message" $padding
    printf "+%${width}s+\n" | tr ' ' '-'
}

# Function to get user input for distro selection
get_distro() {
    while true; do
        echo "Select your Linux distribution:"
        echo "1. Ubuntu"
        echo "2. Fedora"
        echo "3. Arch Linux"
        read -p "Enter the number (1-3): " distro_choice

        case $distro_choice in
            1) echo "ubuntu"; return ;;
            2) echo "fedora"; return ;;
            3) echo "arch"; return ;;
            *) echo "Invalid choice. Please try again." ;;
        esac
    done
}

# Check if script is run with sudo
if [ "$EUID" -ne 0 ] && [ "$1" != "--no-sudo" ]; then
    echo "Some installations require sudo permissions."
    echo "If you don't want to run with sudo, use './setup_env.sh --no-sudo' instead."
    exit 1
fi

# Parse command line arguments
no_sudo=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h)
            show_usage
            exit 0
            ;;
        --no-sudo)
            no_sudo=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Get the distro
distro=$(get_distro)

# Set package manager and package list based on distro
case $distro in
    ubuntu)
        pkg_manager="apt-get"
        packages="git tmux ltrace python3 python3-pip vim gcc g++ make gdb strace build-essential libncurses-dev bison flex libssl-dev libelf-dev fakeroot ccache libncurses-dev libncurses5-dev curl zsh gettext libtool libtool-bin autoconf automake cmake pkg-config unzip"
        ;;
    fedora)
        pkg_manager="dnf"
        packages="git tmux ltrace python3 python3-pip vim gcc gcc-c++ make gdb strace kernel-devel ncurses-devel bison flex openssl-devel elfutils-libelf-devel fakeroot ccache curl zsh gettext libtool autoconf automake cmake pkg-config unzip"
        ;;
    arch)
        pkg_manager="pacman"
        packages="git tmux ltrace python python-pip vim gcc make gdb strace base-devel ncurses bison flex openssl libelf fakeroot ccache curl zsh gettext libtool autoconf automake cmake pkg-config unzip"
        ;;
esac

# Install packages
log_message "Installing packages"
if [ "$no_sudo" = true ]; then
    $pkg_manager install -y $packages
else
    sudo $pkg_manager install -y $packages
fi

# Install Oh My Zsh
log_message "Installing Oh My Zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Change default shell to zsh
log_message "Changing default shell to zsh"
if [ "$no_sudo" = true ]; then
    chsh -s $(which zsh)
else
    sudo chsh -s $(which zsh) $USER
fi

# Configure Oh My Zsh theme
log_message "Configuring Oh My Zsh theme"
cat > ~/.oh-my-zsh/themes/robbyrussell.zsh-theme << EOL
PROMPT="%{$fg[green]%}%n%{$fg_bold[white]%}@%{$fg_bold[green]%}%m %(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{💀%} ) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
EOL

# Create scripts directory and add to PATH
log_message "Creating scripts directory and adding to PATH"
mkdir -p ~/scripts
echo 'export PATH="$HOME/scripts:$PATH"' >> ~/.zshrc

# Install Neovim
log_message "Installing Neovim"
wget https://github.com/neovim/neovim/archive/refs/tags/v0.10.0.tar.gz
tar xzvf v0.10.0.tar.gz
cd neovim-0.10.0
make CMAKE_BUILD_TYPE=Release
if [ "$no_sudo" = true ]; then
    make install
else
    sudo make install
fi
cd ..
rm -rf neovim-0.10.0 v0.10.0.tar.gz

# Configure Neovim
log_message "Configuring Neovim"
git clone https://github.com/manitofigh/nvim.git ~/.config/nvim

log_message "Setup complete!"
echo "Please log out and log back in for all changes to take effect."
