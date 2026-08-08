#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"

# NeoVim
NVIM_CONFIG_PATH="$XDG_CONFIG_DIR/nvim"
NVIM_DATA_PATH="$XDG_DATA_DIR/nvim"
NVIM_STATE_PATH="$XDG_STATE_DIR/nvim"
NVIM_FILES="$ROOT/nvim"

# Tmux
TMUX_CONFIG_PATH="$XDG_CONFIG_DIR/tmux"
TMUX_FILES="$ROOT/tmux"

# Bash
BASH_SCRIPT_PATH="$HOME/.bashrc"
BASH_FILES="$ROOT/bash/bashrc"
BLERC_PATH="$XDG_DATA_DIR/blesh/blerc"
BLERC_FILES="$ROOT/bash/blerc"
STARSHIP_PATH="$XDG_CONFIG_DIR/starship.toml"
STARSHIP_FILES="$ROOT/bash/starship.toml"

VERBOSE=0
DO_BACKUP=0
DO_RESTORE=0
DO_CLEANUP=0
TARGETS=()

log_info() {
    echo "[INFO] $*"
}

log_debug() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "[DEBUG] $*"
    fi
}

log_error() {
    echo "[ERROR] $*" >&2
}

usage() {
    cat <<EOF
Usage: ./install.sh [options] -t <target> [target...]

Targets: neovim, tmux, bash

Options:
  -t, --targets   Targets to install, separated by space.
                  E.g. --targets tmux neovim
  -b, --backup    Back up existing files before installing.
                  The original files are moved to <path>.bak.<timestamp>
  -r, --restore   Restore the latest backup files for the targets
  -c, --cleanup   Remove the currently installed files for the targets
  -v, --verbose   Verbose output
  -h, --help      Show this help
EOF
}

copy_file() {
    local src="$1" dst="$2"
    log_debug "Copying $src to $dst"
    if [ ! -e "$src" ]; then
        log_error "$src not found"
        return 1
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -r "$src/." "$dst/"
    else
        cp "$src" "$dst"
    fi
}

backup_file() {
    local target="$1"
    local backup_path="${target}.bak.$(date +%s)"
    if [ ! -e "$target" ]; then
        log_debug "$target not found, skip backup"
        return 0
    fi
    log_debug "Backing up $target to $backup_path"
    mv "$target" "$backup_path"
}

restore_file() {
    local target="$1"
    local latest
    latest="$(ls -d "${target}".bak.* 2>/dev/null | sort -r | head -n 1 || true)"
    if [ -z "$latest" ]; then
        log_debug "No backup found for $target, skip restore"
        return 0
    fi
    log_debug "Restoring $latest to $target"
    rm -rf "$target"
    mv "$latest" "$target"
}

remove_file() {
    local target="$1"
    log_debug "Removing $target"
    if [ ! -e "$target" ]; then
        log_debug "$target not found, do nothing"
        return 0
    fi
    rm -rf "$target"
}

install_neovim() {
    log_info "Copying files from $NVIM_FILES to $NVIM_CONFIG_PATH"
    copy_file "$NVIM_FILES" "$NVIM_CONFIG_PATH"
    log_info "Installing Neovim completed!"
}

backup_neovim() {
    backup_file "$NVIM_CONFIG_PATH"
    backup_file "$NVIM_DATA_PATH"
    backup_file "$NVIM_STATE_PATH"
}

cleanup_neovim() {
    remove_file "$NVIM_CONFIG_PATH"
    remove_file "$NVIM_DATA_PATH"
    remove_file "$NVIM_STATE_PATH"
}

restore_neovim() {
    restore_file "$NVIM_CONFIG_PATH"
    restore_file "$NVIM_DATA_PATH"
    restore_file "$NVIM_STATE_PATH"
}

install_tmux() {
    log_info "Copying files from $TMUX_FILES to $TMUX_CONFIG_PATH"
    copy_file "$TMUX_FILES" "$TMUX_CONFIG_PATH"
    log_info "Installing Tmux completed!"
}

backup_tmux() {
    backup_file "$TMUX_CONFIG_PATH"
}

cleanup_tmux() {
    remove_file "$TMUX_CONFIG_PATH"
}

restore_tmux() {
    restore_file "$TMUX_CONFIG_PATH"
}

install_bash() {
    log_info "Copying files from $BASH_FILES to $BASH_SCRIPT_PATH"
    copy_file "$BASH_FILES" "$BASH_SCRIPT_PATH"
    copy_file "$BLERC_FILES" "$BLERC_PATH"
    copy_file "$STARSHIP_FILES" "$STARSHIP_PATH"
    log_info "Installing Bash completed!"
}

backup_bash() {
    backup_file "$BASH_SCRIPT_PATH"
    backup_file "$STARSHIP_PATH"
    backup_file "$BLERC_PATH"
}

cleanup_bash() {
    remove_file "$BASH_SCRIPT_PATH"
    remove_file "$BLERC_PATH"
    remove_file "$STARSHIP_PATH"
}

restore_bash() {
    restore_file "$BASH_SCRIPT_PATH"
    restore_file "$STARSHIP_PATH"
    restore_file "$BLERC_PATH"
}

is_valid_target() {
    case "$1" in
        neovim|tmux|bash) return 0 ;;
        *) return 1 ;;
    esac
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -t|--targets)
                shift
                while [ $# -gt 0 ] && [[ "$1" != -* ]]; do
                    TARGETS+=("$1")
                    shift
                done
                ;;
            -b|--backup)
                DO_BACKUP=1
                shift
                ;;
            -r|--restore)
                DO_RESTORE=1
                shift
                ;;
            -c|--cleanup)
                DO_CLEANUP=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [ "${#TARGETS[@]}" -eq 0 ]; then
        log_info "No targets specified, do nothing"
        exit 0
    fi

    for target in "${TARGETS[@]}"; do
        if ! is_valid_target "$target"; then
            log_error "Unknown target: $target. Valid values are: neovim, tmux, bash"
            exit 1
        fi
        if [ "$DO_BACKUP" -eq 1 ]; then
            "backup_${target}"
        fi
        if [ "$DO_RESTORE" -eq 1 ]; then
            "restore_${target}"
        fi
        if [ "$DO_CLEANUP" -eq 1 ]; then
            "cleanup_${target}"
        fi
        "install_${target}"
    done
}

main "$@"
