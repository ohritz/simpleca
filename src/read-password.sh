#!/usr/bin/env bash
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling
trap cleanup_tty ERR SIGINT SIGTERM

stty -echo
IFS= read -r passwd
stty echo
printf "\n"
printf '%s\n' "$passwd"
