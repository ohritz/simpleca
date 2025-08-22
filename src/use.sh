#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling
. "${SCRIPT_DIR}/common.sh"
. "${SCRIPT_DIR}/config.sh"

print_use_usage() {
	cat <<'USAGE'
simpleca use - Set default CA

Usage:
  simpleca use --ca <id>
USAGE
}

run_use() {
	if [[ -z "${CA_ID:-}" ]]; then
		print_use_usage
		fatal "use requires --ca <id>" 2
	fi
	registry_set_default "$CA_ID"
}

run_use "$@"
