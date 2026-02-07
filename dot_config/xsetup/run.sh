#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Logging helper functions ---
info() { echo -e "\033[34m››› $1\033[0m"; }
success() { echo -e "\033[32m✅✅✅ $1\033[0m"; }
error() { echo -e "\033[31m❌❌❌ $1\033[0m"; exit 1; }

# --- Functional components ---

display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "This script sets up a development environment on a fresh Ubuntu system."
    echo
    echo "Options:"
    echo "  --profile <name>      Set the installation profile. Default is 'mini'."
    echo "                          - mini:  Installs Essential base tools (Eza, Neovim, Zellij, etc.)."
    echo "                          - full:  Includes 'mini' + Recommended workflow tools (AstroVim, Lazygit, Bat, etc.)."
    echo "                          - extra: Includes 'full' + Situational/specialized tools (Yazi, Dust, etc.)."
    echo "  --chezmoi <REPO_URL>  Restore dotfiles from a Git repository using Chezmoi after setup."
    echo "  --set-zsh-default     Set Zsh as the default login shell for the user."
    echo "  --help                Display this help message."
}

setup_system_dependencies() {
    info "Stage 1: Setting up base system dependencies via APT..."
    if [ -f /etc/os-release ]; then . /etc/os-release; else error "Cannot determine Ubuntu version."; fi

    # Detect architecture to determine appropriate mirror
    local arch
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l) arch="armhf" ;;
        ppc64el) arch="ppc64el" ;;
        riscv64) arch="riscv64" ;;
        s390x) arch="s390x" ;;
        *) error "Unsupported architecture: $(uname -m)" ;;
    esac

    info "Detected architecture: $arch"

    DEFAULT_SOURCES_FILE="/etc/apt/sources.list.d/ubuntu.sources"
    if [ -f "$DEFAULT_SOURCES_FILE" ]; then
        info "Disabling default .sources format to enforce custom sources.list..."
        [ ! -f "${DEFAULT_SOURCES_FILE}.bak" ] && $SUDO cp "$DEFAULT_SOURCES_FILE" "${DEFAULT_SOURCES_FILE}.bak"
        $SUDO tee "$DEFAULT_SOURCES_FILE" > /dev/null <<EOF
# Intentionally disabled by setup script.
EOF
    fi

    # Choose appropriate mirror based on architecture
    local mirror_base
    if [ "$arch" = "x86_64" ]; then
        info "Configuring APT to use Tsinghua University mirror (x86_64)..."
        mirror_base="https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
    else
        info "Configuring APT to use Tsinghua University Ubuntu Ports mirror ($arch)..."
        mirror_base="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports"
    fi

    $SUDO tee /etc/apt/sources.list > /dev/null <<EOF
deb ${mirror_base}/ ${VERSION_CODENAME} main restricted universe multiverse
deb ${mirror_base}/ ${VERSION_CODENAME}-updates main restricted universe multiverse
deb ${mirror_base}/ ${VERSION_CODENAME}-backports main restricted universe multiverse
deb ${mirror_base}/ ${VERSION_CODENAME}-security main restricted universe multiverse
EOF

    info "Updating package lists from mirror..."
    $SUDO apt-get update

    info "Installing OS-level packages and build dependencies for asdf..."
    $SUDO apt-get install -y --no-install-recommends \
        build-essential git curl unzip jq \
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncurses5-dev libffi-dev \
        zsh bat ripgrep fd-find

    $SUDO ln -sf /usr/bin/fdfind /usr/local/bin/fd
}

# --- Install asdf binary using GitHub API (more reliable than hardcoded URLs) ---
install_asdf() {
    local user_name="${SUDO_USER:-$(whoami)}"
    local user_home; user_home=$(getent passwd "$user_name" | cut -d: -f6)
    local asdf_dir="$user_home/.asdf"

    info "Stage 2: Installing asdf binary via GitHub API for user '$user_name'..."

    # Detect architecture
    local arch
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l) arch="armv7" ;;
        *) error "Unsupported architecture: $(uname -m)" ;;
    esac

    info "Detected architecture: $arch"

    # Remove old installation if it exists
    if [ -d "$asdf_dir" ]; then
        info "Removing old asdf installation..."
        if [ "$(whoami)" == "$user_name" ]; then
            rm -rf "$asdf_dir"
        else
            sudo -u "$user_name" rm -rf "$asdf_dir"
        fi
    fi

    # Create asdf directory
    if [ "$(whoami)" == "$user_name" ]; then
        mkdir -p "$asdf_dir/bin"
    else
        sudo -u "$user_name" mkdir -p "$asdf_dir/bin"
    fi

    info "Fetching latest asdf release URL from GitHub API..."
    local download_url
    download_url=$(curl -s https://api.github.com/repos/asdf-vm/asdf/releases/latest | \
        jq -r ".assets[] | select(.name | endswith(\".tar.gz\") and contains(\"linux-${arch}\")) | .browser_download_url")

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        error "Failed to get download URL for linux-${arch}"
    fi

    info "Download URL: $download_url"

    # Download and extract
    local temp_dir="/tmp/asdf-install-$$"
    mkdir -p "$temp_dir"

    info "Downloading and extracting asdf..."
    if ! curl -fsSL "$download_url" | tar -xz -C "$temp_dir"; then
        rm -rf "$temp_dir"
        error "Failed to download or extract asdf"
    fi

    # Debug: Check what was actually extracted
    info "Checking extracted contents..."
    ls -la "$temp_dir"

    # Find the asdf binary (could be in different locations)
    local asdf_binary=""
    if [ -f "$temp_dir"/asdf ]; then
        asdf_binary="$temp_dir/asdf"
    elif [ -f "$temp_dir"/bin/asdf ]; then
        asdf_binary="$temp_dir/bin/asdf"
    elif [ -f "$temp_dir"/asdf*/asdf ]; then
        asdf_binary="$temp_dir"/asdf*/asdf
    elif [ -f "$temp_dir"/asdf*/bin/asdf ]; then
        asdf_binary="$temp_dir"/asdf*/bin/asdf
    else
        info "Searching for asdf binary in extracted files..."
        find "$temp_dir" -name "asdf" -type f | head -1 | read asdf_binary
    fi

    if [ -z "$asdf_binary" ] || [ ! -f "$asdf_binary" ]; then
        info "Available files in temp directory:"
        find "$temp_dir" -type f
        rm -rf "$temp_dir"
        error "Could not find asdf binary in extracted files"
    fi

    info "Found asdf binary at: $asdf_binary"

    # Move the binary to the correct location
    if [ "$(whoami)" == "$user_name" ]; then
        cp "$asdf_binary" "$asdf_dir/bin/asdf"
        chmod +x "$asdf_dir/bin/asdf"
    else
        sudo -u "$user_name" cp "$asdf_binary" "$asdf_dir/bin/asdf"
        sudo -u "$user_name" chmod +x "$asdf_dir/bin/asdf"
    fi

    rm -rf "$temp_dir"

    info "Configuring shell for asdf v0.16.0+ binary..."
    local zshrc_path="$user_home/.zshrc"
    sudo -u "$user_name" touch "$zshrc_path"

    # Remove old configuration lines if they exist
    sudo -u "$user_name" sed -i '/asdf.sh/d' "$zshrc_path"
    sudo -u "$user_name" sed -i '/ASDF_DATA_DIR/d' "$zshrc_path"
    sudo -u "$user_name" sed -i '/asdf.*setup/d' "$zshrc_path"

    # Add v0.16.0+ configuration
    if ! grep -q "ASDF_DATA_DIR" "$zshrc_path"; then
        {
            echo -e "\n# --- asdf v0.16.0+ binary setup ---"
            echo "export ASDF_DATA_DIR=\"$asdf_dir\""
            echo "export PATH=\"\$ASDF_DATA_DIR/bin:\$ASDF_DATA_DIR/shims:\$PATH\""
        } | sudo -u "$user_name" tee -a "$zshrc_path" > /dev/null
        info "asdf binary configured in $zshrc_path."
    else
        info "asdf already configured in $zshrc_path."
    fi
}

install_asdf_plugins() {
    local user_name="${SUDO_USER:-$(whoami)}"
    local profile=$1
    shift
    local plugins_to_install=("$@")

    info "Stage 3: Installing '$profile' profile tools via asdf..."
    info "Running installation command as user '$user_name'..."

    # Use a heredoc to pipe the script to a new shell for robust execution
    sudo -iu "$user_name" -- bash -s -- "${plugins_to_install[@]}" <<'EOF'
set -e

# This script block is now running inside the new shell as the correct user.
# Set up the asdf environment for this subshell session.
export ASDF_DATA_DIR="$HOME/.asdf"
export PATH="$ASDF_DATA_DIR/bin:$ASDF_DATA_DIR/shims:$PATH"

if ! command -v asdf > /dev/null; then
    echo "Error: asdf command not found in subshell. PATH might be incorrect." >&2
    exit 1
fi

echo "--- Installing asdf plugins: $@"
for plugin in "$@"; do
    echo "--- Processing plugin: ${plugin} ---"
    if ! asdf plugin list | grep -q "^${plugin}$"; then
        # Use custom repository URLs for specific plugins
        case "${plugin}" in
            eza)
                asdf plugin add "${plugin}" https://github.com/pauloedurezende/asdf-eza.git
                ;;
            zoxide)
                asdf plugin add "${plugin}" https://github.com/pauloedurezende/asdf-zoxide.git
                ;;
            fzf)
                asdf plugin add "${plugin}" https://github.com/pauloedurezende/asdf-fzf.git
                ;;
            *)
                asdf plugin add "${plugin}"
                ;;
        esac
    else
        echo "Plugin '${plugin}' already exists."
    fi

    # Special handling for Python: install both latest and 3.10.15
    if [ "${plugin}" == "python" ]; then
        echo "--- Installing Python 3.10.15... ---"
        asdf install python 3.10.15
        echo "--- Installing latest version of Python... ---"
        asdf install python latest
        echo "--- Setting global version to latest (with 3.10.15 as fallback)... ---"
        asdf global python latest 3.10.15
    else
        echo "--- Installing latest version of ${plugin}... ---"
        asdf install "${plugin}" latest
        echo "--- Setting global version for ${plugin}... ---"
        asdf set -u "${plugin}" latest
    fi
done

# Special post-install handling for opencommit
for plugin in "$@"; do
    if [ "$plugin" == "nodejs" ]; then
        echo "--- Node.js installed. Installing global npm package: opencommit ---"
        asdf reshim nodejs
        npm install -g opencommit
        break
    fi
done
EOF
}

# ... [The rest of the functions: install_profile_apt_packages, configure_tools, setup_chezmoi, set_default_shell, cleanup] ...
# ... They are correct and unchanged from the previous complete version ...
install_profile_apt_packages() {
    local profile=$1
    if [[ "$profile" == "extra" ]]; then
        info "Installing APT dependencies for 'Extra' profile..."
        $SUDO apt-get install -y --no-install-recommends ffmpegthumbnailer unar
    fi
}
configure_tools() {
    local profile=$1
    if [[ "$profile" == "full" || "$profile" == "extra" ]]; then
        info "Performing post-install configurations for 'Full/Extra' profile..."
        info "Setting up AstroVim (v4 method)..."
        local user_name="${SUDO_USER:-$(whoami)}"
        local user_home; user_home=$(getent passwd "$user_name" | cut -d: -f6)
        local nvim_config_dir="$user_home/.config/nvim"
        if [ ! -d "$nvim_config_dir" ]; then
            info "Cloning AstroVim template for user '$user_name'..."
            local clone_cmd="git clone --depth 1 https://github.com/AstroNvim/template \"$nvim_config_dir\" && rm -rf \"$nvim_config_dir/.git\""
            if [ "$(whoami)" == "$user_name" ]; then bash -c "$clone_cmd"; else sudo -iu "$user_name" -- bash -c "$clone_cmd"; fi
        else
            info "AstroVim config directory already exists, skipping clone."
        fi
    fi
}
setup_chezmoi() {
    local repo_url=$1
    local target_user="${SUDO_USER:-$(whoami)}"
    info "Restoring dotfiles for user '$target_user' from $repo_url..."

    sudo -iu "$target_user" -- bash -s -- "$repo_url" <<'EOF'
set -e
export ASDF_DATA_DIR="$HOME/.asdf"
export PATH="$ASDF_DATA_DIR/bin:$ASDF_DATA_DIR/shims:$PATH"
if ! command -v chezmoi &> /dev/null; then echo "Error: chezmoi not on path in subshell" >&2; exit 1; fi
chezmoi init --apply "$1"
EOF
    success "Chezmoi dotfiles restored."
}
set_default_shell() {
    local target_user="${SUDO_USER:-$(whoami)}"
    info "Setting default shell to Zsh for user '$target_user'..."
    if ! command -v zsh &> /dev/null; then error "Zsh is not installed."; return 1; fi
    local zsh_path; zsh_path=$(command -v zsh)
    local current_shell; current_shell=$(getent passwd "$target_user" | cut -d: -f7)
    if [ "$current_shell" = "$zsh_path" ]; then info "Zsh is already the default shell for '$target_user'."; else sudo chsh -s "$zsh_path" "$target_user"; success "Default shell for '$target_user' has been set to $zsh_path."; fi
}
cleanup() {
    info "Cleaning up APT cache and unused packages..."; $SUDO apt-get autoremove -y; $SUDO apt-get clean; $SUDO rm -rf /var/lib/apt/lists/*
    success "Cleanup complete."
}


# --- Script Entrypoint ---
main() {
    PROFILE="mini"; USE_CHEZMOI=false; CHEZMOI_REPO=""; SET_ZSH_DEFAULT=false
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --profile) if [ -z "$2" ] || ! [[ "$2" =~ ^(mini|full|extra)$ ]]; then error "Invalid profile '$2'."; fi; PROFILE="$2"; shift 2;;
            --chezmoi) if [ -z "$2" ]; then error "--chezmoi option requires a URL."; fi; USE_CHEZMOI=true; CHEZMOI_REPO="$2"; shift 2;;
            --set-zsh-default) SET_ZSH_DEFAULT=true; shift 1;;
            --help) display_help; exit 0;;
            *) error "Unknown option: $1";;
        esac
    done

    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO="sudo"; if ! command -v sudo >/dev/null; then error "This script needs sudo."; exit 1; fi
    else
        info "Running as root. Performing a self-healing bootstrap..."
        export DEBIAN_FRONTEND=noninteractive
        rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources
        if [ -f /etc/os-release ]; then . /etc/os-release; else error "Bootstrap failed: Cannot determine Ubuntu version."; fi
        
        # Detect architecture for bootstrap mirror selection
        local arch
        case "$(uname -m)" in
            x86_64) arch="x86_64" ;;
            aarch64|arm64) arch="arm64" ;;
            armv7l) arch="armhf" ;;
            ppc64el) arch="ppc64el" ;;
            riscv64) arch="riscv64" ;;
            s390x) arch="s390x" ;;
            *) error "Unsupported architecture: $(uname -m)" ;;
        esac
        
        # Choose appropriate mirror based on architecture
        local mirror_base
        if [ "$arch" = "x86_64" ]; then
            mirror_base="http://archive.ubuntu.com/ubuntu"
        else
            mirror_base="http://ports.ubuntu.com/ubuntu-ports"
        fi
        
        tee /etc/apt/sources.list > /dev/null <<EOF
deb ${mirror_base}/ ${VERSION_CODENAME} main restricted universe multiverse
deb ${mirror_base}/ ${VERSION_CODENAME}-updates main restricted universe multiverse
deb ${mirror_base}/ ${VERSION_CODENAME}-security main restricted universe multiverse
EOF
        apt-get update -qq
        apt-get install -y -qq sudo curl git liblzma-dev
    fi

    if ! ( [ -f /etc/os-release ] && grep -q "ID=ubuntu" /etc/os-release ); then error "This script is designed for Ubuntu systems only."; fi

    mini_plugins=("python" "chezmoi" "rust" "eza" "neovim" "uv" "zellij" "fzf" "llvm")
    full_plugins=("zoxide" "lazygit" "ctop")
    extra_plugins=("dust" "nodejs" "golang")

    declare -a plugins_to_install
    case "$PROFILE" in
        mini) plugins_to_install=("${mini_plugins[@]}");;
        full) plugins_to_install=("${mini_plugins[@]}" "${full_plugins[@]}");;
        extra) plugins_to_install=("${mini_plugins[@]}" "${full_plugins[@]}" "${extra_plugins[@]}");;
    esac

    setup_system_dependencies
    install_profile_apt_packages "$PROFILE"
    install_asdf
    install_asdf_plugins "$PROFILE" "${plugins_to_install[@]}"
    configure_tools "$PROFILE"

    if [ "$USE_CHEZMOI" = true ]; then
        setup_chezmoi "$CHEZMOI_REPO"
    fi
    if [ "$SET_ZSH_DEFAULT" = true ]; then
        set_default_shell
    fi
    cleanup
    success "Your Ubuntu system setup is complete!"
}
main "$@"
