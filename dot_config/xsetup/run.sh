#!/usr/bin/env bash

# ==============================================================================
# Linux (Ubuntu/Debian) Development Environment Setup
# ==============================================================================
# Uses mise as the sole version/tool manager. APT is only used for essential
# build dependencies. Designed for portability across containers, VPS, and
# bare-metal systems.
#
# Tools managed by mise (profile-based):
#   mini:  Python, uv, Neovim, fzf, zoxide, chezmoi, zellij, starship, jq, ripgrep, fd
#   full:  mini + Node.js, Go, Rust, eza, lazygit, delta, bat
#   extra: full + dust, yazi, btop, procs, tealdeer, xh, gping, LLVM/Clang, TinyTeX
# ==============================================================================

set -e

# --- Logging helper functions ---
info() { echo -e "\033[34m››› $1\033[0m"; }
success() { echo -e "\033[32m✅ $1\033[0m"; }
error() { echo -e "\033[31m❌ $1\033[0m"; exit 1; }

# --- Functional components ---

display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "This script sets up a development environment on a fresh Ubuntu/Debian system."
    echo "Nearly all tools are installed via mise for reproducibility across environments."
    echo
    echo "Options:"
    echo "  --profile <name>      Set the installation profile. Default is 'mini'."
    echo "                          - mini:  Python, uv, Neovim, fzf, zoxide, chezmoi, zellij,"
    echo "                                   starship, jq, ripgrep, fd."
    echo "                          - full:  mini + Node.js, Go, Rust, eza, lazygit, delta, bat."
    echo "                          - extra: full + dust, yazi, btop, procs, tealdeer, xh, gping, LLVM, TinyTeX."
    echo "  --chezmoi <url>       Initialize and apply dotfiles from a chezmoi repo."
    echo "                          Example: --chezmoi https://github.com/user/dotfiles.git"
    echo "  --set-zsh-default     Set Zsh as the default login shell for the user."
    echo "  --help                Display this help message."
}

setup_system_dependencies() {
    info "Stage 1: Setting up base system dependencies via APT..."
    if [ -f /etc/os-release ]; then . /etc/os-release; else error "Cannot determine OS version."; fi

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

    info "Installing minimal OS-level packages and build dependencies..."
    $SUDO apt-get install -y --no-install-recommends \
        build-essential git curl wget unzip zsh \
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev libncurses5-dev libffi-dev liblzma-dev
}

install_profile_apt_packages() {
    local profile=$1
    if [[ "$profile" == "extra" ]]; then
        info "Installing APT dependencies for 'extra' profile..."
        $SUDO apt-get install -y --no-install-recommends \
            ffmpegthumbnailer cmake ninja-build python3
    fi
}

install_mise() {
    local user_name="${SUDO_USER:-$(whoami)}"
    local user_home; user_home=$(getent passwd "$user_name" | cut -d: -f6)

    info "Stage 2: Installing mise for user '$user_name'..."

    # Remove old asdf installation if it exists (migration cleanup)
    local asdf_dir="$user_home/.asdf"
    if [ -d "$asdf_dir" ]; then
        info "Removing old asdf installation at $asdf_dir..."
        if [ "$(whoami)" == "$user_name" ]; then
            rm -rf "$asdf_dir"
        else
            sudo -u "$user_name" rm -rf "$asdf_dir"
        fi
    fi

    # Install mise as the target user
    if [ "$(whoami)" == "$user_name" ]; then
        curl https://mise.run | sh
    else
        sudo -iu "$user_name" -- bash -c 'curl https://mise.run | sh'
    fi

    # Verify installation
    local mise_bin="$user_home/.local/bin/mise"
    if [ ! -f "$mise_bin" ]; then
        error "mise binary not found at $mise_bin after installation."
    fi

    info "mise installed successfully at $mise_bin"
}

install_mise_tools() {
    local user_name="${SUDO_USER:-$(whoami)}"
    local profile=$1

    info "Stage 3: Installing '$profile' profile tools via mise..."

    # Build the tool list based on profile
    local -a tools=()

    # --- mini profile tools (always included) ---
    tools+=("python@3.10.15" "python@latest")
    tools+=("uv@latest")
    tools+=("neovim@latest")
    tools+=("fzf@latest")
    tools+=("zoxide@latest")
    tools+=("chezmoi@latest")
    tools+=("zellij@latest")
    tools+=("starship@latest")
    tools+=("jq@latest")
    tools+=("ripgrep@latest")
    tools+=("fd@latest")

    # --- full profile tools (mini + these) ---
    if [[ "$profile" == "full" || "$profile" == "extra" ]]; then
        tools+=("node@latest")
        tools+=("go@latest")
        tools+=("rust@latest")
        tools+=("eza@latest")
        tools+=("lazygit@latest")
        tools+=("delta@latest")
        tools+=("bat@latest")
    fi

    # --- extra profile tools (full + these) ---
    if [[ "$profile" == "extra" ]]; then
        tools+=("dust@latest")
        tools+=("yazi@latest")
        tools+=("btop@latest")
        tools+=("aqua:dalance/procs@latest")
        tools+=("xh@latest")
        tools+=("gping@latest")
        tools+=("tinytex@latest")
        tools+=("clang@latest")
    fi

    info "Tools to install: ${tools[*]}"

    # Execute as the correct user via heredoc
    local run_as
    if [ "$(whoami)" == "$user_name" ]; then
        run_as="bash -s --"
    else
        run_as="sudo -iu $user_name -- bash -s --"
    fi

    $run_as "$profile" "${tools[@]}" <<'MISE_EOF'
set -e

PROFILE="$1"
shift
TOOLS=("$@")

# Set up mise environment for this subshell
export PATH="$HOME/.local/bin:$PATH"

if ! command -v mise > /dev/null; then
    echo "Error: mise command not found. PATH=$PATH" >&2
    exit 1
fi

# For extra profile, register the LLVM plugin (requires custom plugin URL)
if [[ "$PROFILE" == "extra" ]]; then
    echo "--- Adding mise-llvm plugin ---"
    mise plugin add clang https://github.com/mise-plugins/mise-llvm.git 2>/dev/null || true

    # LLVM compilation needs Python on PATH. Install non-LLVM tools first,
    # activate mise so Python shims are available, then install clang/LLVM.
    NON_LLVM=()
    for t in "${TOOLS[@]}"; do
        [[ "$t" != clang@* ]] && NON_LLVM+=("$t")
    done

    echo "--- Installing tools via mise (phase 1: non-LLVM) ---"
    mise use -g -y "${NON_LLVM[@]}"
    mise reshim
    eval "$(mise activate bash)"

    echo "--- Installing clang/LLVM via mise (phase 2: requires Python) ---"
    mise use -g -y clang@latest
    mise reshim
else
    echo "--- Installing tools via mise ---"
    mise use -g -y "${TOOLS[@]}"
    mise reshim
fi

# Post-install tasks (require mise activation for shims)
eval "$(mise activate bash)"

if [[ "$PROFILE" == "full" || "$PROFILE" == "extra" ]]; then
    # opencommit via npm (requires Node.js)
    if command -v node > /dev/null 2>&1; then
        echo "--- Installing opencommit via npm ---"
        npm install -g opencommit
        mise reshim
    fi

    # tealdeer via cargo (requires Rust; no pre-built binary in mise registry)
    if command -v cargo > /dev/null 2>&1; then
        echo "--- Installing tealdeer via cargo ---"
        cargo install tealdeer
        mise reshim
    fi
fi
MISE_EOF

    success "mise tool installation complete for '$profile' profile."
}

configure_tools() {
    local profile=$1
    if [[ "$profile" == "full" || "$profile" == "extra" ]]; then
        info "Performing post-install configurations for 'full/extra' profile..."
        info "Setting up AstroVim (v4 method)..."
        local user_name="${SUDO_USER:-$(whoami)}"
        local user_home; user_home=$(getent passwd "$user_name" | cut -d: -f6)
        local nvim_config_dir="$user_home/.config/nvim"
        if [ ! -d "$nvim_config_dir" ]; then
            info "Cloning AstroVim template for user '$user_name'..."
            local clone_cmd="git clone --depth 1 https://github.com/AstroNvim/template \"$nvim_config_dir\" && rm -rf \"$nvim_config_dir/.git\""
            if [ "$(whoami)" == "$user_name" ]; then
                bash -c "$clone_cmd"
            else
                sudo -iu "$user_name" -- bash -c "$clone_cmd"
            fi
        else
            info "AstroVim config directory already exists, skipping clone."
        fi
    fi
}

apply_chezmoi_dotfiles() {
    local repo_url=$1
    local user_name="${SUDO_USER:-$(whoami)}"

    info "Applying dotfiles from chezmoi repo: $repo_url"

    local run_as
    if [ "$(whoami)" == "$user_name" ]; then
        run_as="bash -s --"
    else
        run_as="sudo -iu $user_name -- bash -s --"
    fi

    $run_as "$repo_url" <<'CHEZMOI_EOF'
set -e
REPO_URL="$1"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v chezmoi > /dev/null; then
    echo "Error: chezmoi not found. PATH=$PATH" >&2
    exit 1
fi

eval "$(mise activate bash 2>/dev/null)" || true

echo "--- Running chezmoi init --apply ---"
chezmoi init --apply "$REPO_URL"
echo "--- chezmoi dotfiles applied ---"
CHEZMOI_EOF

    success "Dotfiles applied from $repo_url"
}

set_default_shell() {
    local target_user="${SUDO_USER:-$(whoami)}"
    info "Setting default shell to Zsh for user '$target_user'..."
    if ! command -v zsh &> /dev/null; then error "Zsh is not installed."; return 1; fi
    local zsh_path; zsh_path=$(command -v zsh)
    local current_shell; current_shell=$(getent passwd "$target_user" | cut -d: -f7)
    if [ "$current_shell" = "$zsh_path" ]; then
        info "Zsh is already the default shell for '$target_user'."
    else
        sudo chsh -s "$zsh_path" "$target_user"
        success "Default shell for '$target_user' has been set to $zsh_path."
    fi
}

cleanup() {
    info "Cleaning up APT cache and unused packages..."
    $SUDO apt-get autoremove -y
    $SUDO apt-get clean
    $SUDO rm -rf /var/lib/apt/lists/*
    success "Cleanup complete."
}


# --- Script Entrypoint ---
main() {
    PROFILE="mini"
    SET_ZSH_DEFAULT=false
    CHEZMOI_REPO=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --profile)
                if [ -z "$2" ] || ! [[ "$2" =~ ^(mini|full|extra)$ ]]; then
                    error "Invalid profile '$2'. Must be: mini, full, extra"
                fi
                PROFILE="$2"; shift 2 ;;
            --chezmoi)
                if [ -z "$2" ]; then
                    error "--chezmoi requires a repository URL."
                fi
                CHEZMOI_REPO="$2"; shift 2 ;;
            --set-zsh-default) SET_ZSH_DEFAULT=true; shift 1 ;;
            --help) display_help; exit 0 ;;
            *) error "Unknown option: $1" ;;
        esac
    done

    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO="sudo"
        if ! command -v sudo >/dev/null; then error "This script needs sudo."; exit 1; fi
    else
        info "Running as root. Performing a self-healing bootstrap..."
        export DEBIAN_FRONTEND=noninteractive
        rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources
        if [ -f /etc/os-release ]; then . /etc/os-release; else error "Bootstrap failed: Cannot determine OS version."; fi

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

    if ! ( [ -f /etc/os-release ] && grep -qE "ID=(ubuntu|debian)" /etc/os-release ); then
        error "This script is designed for Ubuntu/Debian systems only."
    fi

    setup_system_dependencies
    install_profile_apt_packages "$PROFILE"
    install_mise
    install_mise_tools "$PROFILE"

    configure_tools "$PROFILE"

    if [ -n "$CHEZMOI_REPO" ]; then
        apply_chezmoi_dotfiles "$CHEZMOI_REPO"
    fi

    if [ "$SET_ZSH_DEFAULT" = true ]; then
        set_default_shell
    fi

    cleanup
    success "Your development environment setup is complete!"
}
main "$@"
