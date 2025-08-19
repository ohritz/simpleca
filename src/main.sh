#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

# Version information - check multiple sources in order of preference
get_version() {
	# 1. Use baked-in BUILD_VERSION from Docker build if available
	if [[ -n "${BUILD_VERSION:-}" ]]; then
		printf '%s' "$BUILD_VERSION"
		return
	fi

	# 2. Try git if available
	if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
		local git_version
		git_version="$(git describe --tags --always --dirty 2>/dev/null || echo "")"
		if [[ -n "$git_version" ]]; then
			printf '%s' "$git_version"
			return
		fi
	fi

	# 3. Try VERSION file relative to script directory
	local version_file="${SCRIPT_DIR}/VERSION"
	if [[ -f "$version_file" ]]; then
		local file_version
		file_version="$(cat "$version_file" 2>/dev/null | tr -d '\n\r')"
		if [[ -n "$file_version" ]]; then
			printf '%s' "$file_version"
			return
		fi
	fi

	# 4. Fallback to unknown
	printf '%s' "unknown"
}

VERSION="$(get_version)"

print_usage() {
	cat <<'USAGE'
Simple CA

Usage:
  simpleca <command> [options]

Commands:
  init        Initialize root and intermediate CA
  issue       Issue a server certificate
  eject       Archive current CA state
  re-init     Restore CA from archive
  validate    Validate a certificate/chain
  cert-manager  Export cert-manager Issuer/Secret manifests
  version     Print version info
  help        Show this help

Global options:
  -h, --help          Show help
  -q, --quiet         Reduce output
  -v, --verbose       Increase output
      --no-color      Disable colors
      --non-interactive  Fail if input would be prompted

Examples:
  simpleca init
  simpleca issue --cn api.local --sans DNS:api.local,DNS:api
  simpleca validate
USAGE
}

# Load .env if present (without overriding existing env)
load_dotenv ".env" || true

# Check for help or version as first argument
if [[ $# -gt 0 ]]; then
	case "$1" in
		--help|-h|help)
			print_usage
			exit 0
			;;
		--version|version)
			printf 'simpleca %s\n' "$VERSION"
			exit 0
			;;
	esac
fi

# Check for empty command
if [[ $# -eq 0 ]]; then
	print_usage
	exit 0
fi

# Get the subcommand
SUBCOMMAND="$1"
shift

# Dispatch to subcommands
case "$SUBCOMMAND" in
	init)
		. "${SCRIPT_DIR}/init.sh" "$@"
		;;
	issue)
		. "${SCRIPT_DIR}/request-server-cert.sh" "$@"
		;;
	eject)
		. "${SCRIPT_DIR}/eject-ca.sh" "$@"
		;;
	re-init)
		. "${SCRIPT_DIR}/re-init.sh" "$@"
		;;
	validate)
		. "${SCRIPT_DIR}/validate.sh" "$@"
		;;
	cert-manager)
		. "${SCRIPT_DIR}/cert-manager.sh" "$@"
		;;
	version)
		printf 'simpleca %s\n' "$VERSION"
		;;
	help)
		print_usage
		;;
	*)
		# Back-compat: treat as hostname for issue command
		export SERVER_CN="$SUBCOMMAND"
		info "Making request for hostname $SERVER_CN"
		. "${SCRIPT_DIR}/request-server-cert.sh" "$SERVER_CN" "$@"
		;;
esac

