# =============================================================================
# uv Workflow Extensions (conda-like interface)
#
# This wrapper adds `create`, `activate`, `deactivate`, and `list` commands
# to the `uv` executable for streamlined virtual environment management.
# =============================================================================

export UV_ENVS_DIR="$HOME/.uv_envs"
mkdir -p "$UV_ENVS_DIR"

_uv_create() {
    if ! command -v uv &> /dev/null; then
        echo "Error: 'uv' is not installed or not in your PATH." >&2; return 1;
    fi
    if [ -z "$1" ]; then
        echo "Error: Environment name is required." >&2
        echo "Usage: uv create <env_name> [python_version]" >&2; return 1;
    fi
    local env_name="$1"; local python_version="${2:-python3}"; local env_path="$UV_ENVS_DIR/$env_name"
    if [ -d "$env_path" ]; then
        echo "Error: Environment '$env_name' already exists at '$env_path'." >&2; return 1;
    fi
    echo "Creating virtual environment '$env_name' with '$python_version'..."
    command uv venv -p "$python_version" "$env_path"
    if [ $? -eq 0 ]; then
        echo "Successfully created '$env_name'."; echo "To activate it, run: uv activate $env_name"
    else
        echo "Error: Failed to create virtual environment with uv." >&2; return 1;
    fi
}

_uv_activate() {
    local env_name="$1"
    if [ -z "$env_name" ]; then
        if command -v fzf &> /dev/null; then
            env_name=$(ls -1 "$UV_ENVS_DIR" | fzf --prompt="Select environment to activate > ")
            [ -z "$env_name" ] && return 1
        else
            echo "Error: Environment name is required." >&2
            echo "Usage: uv activate <env_name>" >&2; return 1;
        fi
    fi
    local activate_script="$UV_ENVS_DIR/$env_name/bin/activate"
    if [ -f "$activate_script" ]; then
        source "$activate_script"
    else
        echo "Error: Environment '$env_name' not found." >&2
        echo "Available environments:" >&2; _uv_list; return 1;
    fi
}

_uv_deactivate() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate
    else
        echo "No active virtual environment to deactivate."
    fi
}

_uv_list() {
    echo "Available environments in $UV_ENVS_DIR:"
    if [ -n "$(ls -A $UV_ENVS_DIR 2>/dev/null)" ]; then
        ls -1 "$UV_ENVS_DIR"
    else
        echo "(None)"
    fi
}

uv() {
    if ! command -v uv &> /dev/null && [[ "$1" != "create" ]]; then
         echo "Error: 'uv' is not installed or not in your PATH." >&2
         echo "Please install it first: https://github.com/astral-sh/uv" >&2; return 1;
    fi
    case "$1" in
        create|activate|deactivate|list)
            local cmd="_uv_$1"; shift; "$cmd" "$@"
            ;;
        *)
            command uv "$@"
            ;;
    esac
}

_uv_completions() {
    local -a commands=('create' 'activate' 'deactivate' 'list' 'pip' 'venv' 'version' 'help')
    local -a envs
    if (( CURRENT == 2 )); then
        compadd -a commands
    elif (( CURRENT > 2 )); then
        case "${words[2]}" in
            activate)
                envs=(${(f)"$(ls -1 $UV_ENVS_DIR 2>/dev/null)"}); compadd -a envs ;;
            create)
                (( CURRENT == 4 )) && compadd -c python ;;
            *)
                _normal ;;
        esac
    else
      _normal
    fi
}
compdef _uv_completions uv
