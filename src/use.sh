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
  simpleca use <id>

Arguments:
  <id>    CA identifier to set as default

Examples:
  simpleca use acme
  simpleca use my-ca
USAGE
}

# Check if CA exists (either in registry or on disk)
ca_exists() {
	local ca_id=${1:?"ca_id required"}

	# Check if CA exists in registry
	if _have_jq && [[ -f "${REGISTRY_PATH}" ]]; then
		if jq -e --arg id "$ca_id" '.cas[$id]' "${REGISTRY_PATH}" >/dev/null 2>&1; then
			return 0
		fi
	fi

	# Check if CA directory exists on disk
	if [[ -d "${CA_DATA_ROOT}/cas/${ca_id}" ]]; then
		return 0
	fi

	return 1
}

run_use() {
	# Parse positional arguments
	if [[ $# -eq 0 ]]; then
		print_use_usage
		fatal "use requires a CA identifier" 2
	fi

	local ca_id="$1"
	shift

	# Handle help flags
	if [[ "$ca_id" == "-h" || "$ca_id" == "--help" || "$ca_id" == "help" ]]; then
		print_use_usage
		exit 0
	fi

	# Check for extra arguments
	if [[ $# -gt 0 ]]; then
		print_use_usage
		fatal "unexpected arguments: $*" 2
	fi

	# Validate CA exists
	if ! ca_exists "$ca_id"; then
		fatal "CA '$ca_id' not found. Use 'simpleca list' to see available CAs." 1
	fi

	# Set as default
	registry_set_default "$ca_id"
}

run_use "$@"
