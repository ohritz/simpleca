#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

# Also source config helpers for registry operations
. "${SCRIPT_DIR}/config.sh"

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
  export      Archive current CA state
  import      Restore CA from archive
  validate    Validate a certificate/chain
  cert-manager  Export cert-manager Issuer/Secret manifests
  list        List registered CAs
  use         Set default CA
  version     Print version info
  help        Show this help

Global options:
  -h, --help          Show help
  -q, --quiet         Reduce output
  -v, --verbose       Increase output
      --no-color      Disable colors
      --non-interactive  Fail if input would be prompted
      --base-path DIR Override CA base directory (default: ~/.local/share/simple-ca)
      --export-dir DIR Override export directory (default: ~/.local/share/simple-ca/export)
      --config FILE   Registry file path (default: ${XDG_CONFIG_HOME:-$HOME/.config}/simple_ca/config.json)
      --ca ID         Select CA id (uses default from registry if omitted)

Examples:
  simpleca init
  simpleca --base-path /tmp/ca init
  simpleca issue --cn api.local --sans DNS:api.local,DNS:api
  simpleca validate
  simpleca list
  simpleca use acme
  simpleca export
  simpleca import --ca-id acme backup.tar.gz
USAGE
}

# Load .env if present (without overriding existing env)
load_dotenv ".env" || true

# Global flags (parsed before subcommand)
QUIET=0; VERBOSE=0; NO_COLOR=0; NON_INTERACTIVE=0

# Pre-parse help/version and global flags
args=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--help|-h|help) print_usage; exit 0;;
		--version) printf 'simpleca %s\n' "$VERSION"; exit 0;;
		-q|--quiet) QUIET=1; shift; continue;;
		-v|--verbose) VERBOSE=$((VERBOSE+1)); shift; continue;;
		--no-color) NO_COLOR=1; shift; continue;;
		--non-interactive) NON_INTERACTIVE=1; export NON_INTERACTIVE; shift; continue;;
		--base-path)
			if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
				export basePath="$2"
				shift 2; continue
			else fatal "--base-path requires an argument" 2; fi ;;
		--export-dir)
			if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
				export exportDir="$2"
				shift 2; continue
			else fatal "--export-dir requires an argument" 2; fi ;;
		--config)
			if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
				export REGISTRY_PATH="$2"
				shift 2; continue
			else fatal "--config requires a file path" 2; fi ;;
		--config=*)
			export REGISTRY_PATH="${1#--config=}"; shift; continue;;
		--ca)
			if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
				export CA_ID="$2"
				shift 2; continue
			else fatal "--ca requires an identifier" 2; fi ;;
		--ca=*)
			export CA_ID="${1#--ca=}"; shift; continue;;
		--) shift; break;;
		-*) fatal "Unknown option: $1" 2;;
		*) args+=("$1"); shift; break;;
	esac
done



# Remaining args include subcommand and its args
set -- "${args[@]}" "$@"

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
	export)
		. "${SCRIPT_DIR}/export.sh" "$@"
		;;
	import)
		. "${SCRIPT_DIR}/import.sh" "$@"
		;;
	validate)
		. "${SCRIPT_DIR}/validate.sh" "$@"
		;;
	cert-manager)
		. "${SCRIPT_DIR}/cert-manager.sh" "$@"
		;;
	list)
		. "${SCRIPT_DIR}/list.sh" "$@"
		;;
	use)
		. "${SCRIPT_DIR}/use.sh" "$@"
		;;
	version)
		printf 'simpleca %s\n' "$VERSION"
		;;
	help)
		print_usage
		;;
	*)
		# Back-compat: treat as hostname for issue command when it looks like a hostname (no leading dash)
		if [[ "$SUBCOMMAND" != -* ]]; then
			export SERVER_CN="$SUBCOMMAND"
			info "Making request for hostname $SERVER_CN"
			. "${SCRIPT_DIR}/request-server-cert.sh" "$SERVER_CN" "$@"
		else
			fatal "Unknown command: $SUBCOMMAND" 2
		fi
		;;
 esac

