#!/usr/bin/env bash
# Common utilities for Simple CA scripts
# This file should be sourced by all other scripts

# Enhanced error handler with filename
on_err() {
    local line=${1:-?}
    local script_name=${BASH_SOURCE[1]:-unknown}
    printf '[ERR] %s:%s: %s\n' "$(basename "$script_name")" "$line" "Command failed" >&2
    exit 1
}

# Signal handler
on_sig() {
    local script_name=${BASH_SOURCE[1]:-unknown}
    printf '[ERR] %s: Interrupted\n' "$(basename "$script_name")" >&2
    exit 130
}

# Setup error handling for the calling script
setup_error_handling() {
    set -Eeuo pipefail
    IFS=$'\n\t'
    umask 077
    trap 'on_err $LINENO' ERR
    trap 'on_sig' SIGINT SIGTERM
}

# Logging functions
fatal() {
    local script_name
    if [[ ${#BASH_SOURCE[@]} -gt 1 ]]; then
        script_name=${BASH_SOURCE[1]}
    else
        script_name=${BASH_SOURCE[0]:-unknown}
    fi
    printf '[ERR] %s: %s\n' "$(basename "$script_name")" "$1" >&2
    exit "${2:-1}"
}

info()  {
    [[ ${QUIET:-0} -eq 1 ]] || printf '[INFO] %s\n' "$1"
}

debug() {
    if [[ ${VERBOSE:-0} -ge 1 ]]; then
        printf '[DBG] %s\n' "$1"
    fi
    return 0
}

# Utility functions
require_cmd() {
    local bin=${1:?}
    command -v "$bin" >/dev/null 2>&1 || fatal "Required command not found: $bin"
}

# TTY cleanup for password reading
cleanup_tty() {
    stty echo 2>/dev/null || true
}

# Read a password using configured or discoverable helper
read_password() {
    local reader="${READ_PASSWORD_CMD:-}"
    if [[ -n "$reader" ]]; then
        . "$reader"
        return 0
    fi
    if command -v read-password.sh >/dev/null 2>&1; then
        . "$(command -v read-password.sh)"
        return 0
    fi
    if [[ -x /opt/tools/read-password.sh ]]; then
        . /opt/tools/read-password.sh
        return 0
    fi
    fatal "Password reader not found (set READ_PASSWORD_CMD or ensure read-password.sh in PATH)" 2
}
