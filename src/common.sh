#!/usr/bin/env bash
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first (only if not already sourced)
if [[ -z "${_UTILS_SOURCED:-}" ]]; then
	. "${SCRIPT_DIR}/utils.sh"
	setup_error_handling
	_UTILS_SOURCED=1
fi

# Usage text for help handling
USAGE="Simple CA

Usage:
  simpleca <command|hostname> [options]

Commands:
  init        Initialize root and intermediate CA
  eject       Archive current CA state
  re-init     Restore CA from archive
  validate    Validate a certificate/chain
  version     Print version info
  help        Show this help

Global options:
  -h, --help             Show help
  -q, --quiet            Reduce output
  -v, --verbose          Increase output (repeatable)
      --no-color         Disable colors
      --non-interactive  Fail if input would be prompted

Notes:
  For backward compatibility, passing a hostname directly issues a server certificate."

parse_global_opts() {
	QUIET=${QUIET:-0}; VERBOSE=${VERBOSE:-0}; NO_COLOR=${NO_COLOR:-0}; NON_INTERACTIVE=${NON_INTERACTIVE:-0}
	local help_requested=0
	while getopts ':hqv-:' opt; do
		case "$opt" in
			h) help_requested=1;;
			q) QUIET=1;;
			v) VERBOSE=$((VERBOSE+1));;
			-)
				case "$OPTARG" in
					help) help_requested=1;;
					quiet) QUIET=1;;
					verbose) VERBOSE=$((VERBOSE+1));;
					no-color) NO_COLOR=1;;
					non-interactive) NON_INTERACTIVE=1;;
					*) fatal "Unknown option: --$OPTARG" 2;;
				esac;;
			:) fatal "Missing argument for -$OPTARG" 2;;
			\?) fatal "Unknown option: -$OPTARG" 2;;
		esac
	done
	shift $((OPTIND-1))
	OPTIND=1
	if [[ $help_requested -eq 1 ]]; then
		printf '%s\n' "${USAGE:-}"
		return 1
	fi
	echo "$@"
}

load_dotenv() {
	local f=${1:-".env"}; [[ -f "$f" ]] || return 0
	while IFS='=' read -r k v; do
		[[ "$k" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
		[[ -v $k ]] && continue
		export "$k"="$v"
	done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$f" | sed 's/^export //')
}

# Dependencies
require_cmd bash
require_cmd openssl

# Paths and files
basePath="/opt/ca"
rootCAPath="${basePath}/root"
intermediatePath="${basePath}/intermediate"

rootConfig="/opt/tools/openssl-root.cnf"
intermediateConfig="/opt/tools/openssl-intermediate.cnf"

rootCAKey="${rootCAPath}/private/ca.key.pem"
rootCaCert="${rootCAPath}/certs/ca.cert.pem"

intermediateKey="${intermediatePath}/private/intermediate.key.pem"
intermediateCsr="${intermediatePath}/csr/intermediate.csr.pem"
intermediateCert="${intermediatePath}/certs/intermediate.cert.pem"
certificateChain="${intermediatePath}/certs/ca-chain.cert.pem"

exportDir="/opt/export"

: "${SERVER_CN:=}"
serverKey="${intermediatePath}/private/${SERVER_CN}.key.pem"
serverCsr="${intermediatePath}/csr/${SERVER_CN}.csr"
serverCert="${intermediatePath}/certs/${SERVER_CN}.cert.pem"

outputDir="${basePath}/output/${SERVER_CN}"
serverPem="${outputDir}/${SERVER_CN}.pkcs8.key.pem"
serverPfx="${outputDir}/${SERVER_CN}.pfx"
rootCACertFriendly="${outputDir}/rootCA.crt.pem"
