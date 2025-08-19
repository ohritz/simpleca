#!/usr/bin/env bash
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling



. "${SCRIPT_DIR}/common.sh"

# Parse global options and remaining args
# Check for help first
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
	printf '%s\n' "$USAGE"
	exit 0
fi

_args=$(parse_global_opts "$@")
# shellcheck disable=SC2206
set -- ${_args}

# Load .env if present (without overriding existing env)
load_dotenv ".env" || true

print_usage() { printf '%s\n' "$USAGE"; }

if [[ $# -eq 0 ]]; then
	print_usage
	exit 0
fi

case "$1" in
	init|--init)
		info "Initial Setup of the CA"
		. "${SCRIPT_DIR}/init.sh"
		;;
	eject|--eject)
		info "Ejecting the CA"
		. "${SCRIPT_DIR}/eject-ca.sh"
		;;
	re-init|--re-init)
		info "Recreating from tar"
		. "${SCRIPT_DIR}/re-init.sh" "${2:-ca.tar.gz}"
		;;
	validate|--validate)
		. "${SCRIPT_DIR}/validate.sh"
		;;
	version|--version)
		if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
			printf 'simpleca %s\n' "$(git describe --tags --always --dirty 2>/dev/null || echo unknown)"
		else
			printf 'simpleca %s\n' "unknown"
		fi
		;;
	help|--help)
		print_usage
		;;
	*)
		# Back-compat: treat as hostname
		export SERVER_CN="$1"
		info "Making request for hostname $SERVER_CN"
		. "${SCRIPT_DIR}/request-server-cert.sh" "$SERVER_CN"
		;;
esac

