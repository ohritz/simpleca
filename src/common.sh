#!/usr/bin/env bash
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first (only if not already sourced)
if [[ -z "${_UTILS_SOURCED:-}" ]]; then
	. "${SCRIPT_DIR}/utils.sh"
	setup_error_handling
	_UTILS_SOURCED=1
fi

# Source config helpers (registry/XDG)
if [[ -z "${_CONFIG_SOURCED:-}" ]]; then
	. "${SCRIPT_DIR}/config.sh"
	_CONFIG_SOURCED=1
fi

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

# Load environment variables with defaults
load_dotenv

# Certificate generation defaults
: "${KEY_TYPE:=ec}"
: "${EC_CURVE:=prime256v1}"
: "${RSA_BITS:=3072}"
: "${LEAF_DAYS:=398}"
: "${PKCS8_ITER:=204000}"
: "${PFX_ITER:=204000}"
: "${SERVER_SANS:=}"

# Validate key type
case "$KEY_TYPE" in
	ec|rsa) ;;
	*) fatal "Invalid KEY_TYPE: $KEY_TYPE. Must be 'ec' or 'rsa'" 1 ;;
esac

# Validate EC curve
case "$EC_CURVE" in
	prime256v1|secp384r1) ;;
	*) fatal "Invalid EC_CURVE: $EC_CURVE. Must be 'prime256v1' or 'secp384r1'" 1 ;;
esac

# Validate RSA bits
if [[ "$KEY_TYPE" == "rsa" ]] && [[ "${RSA_BITS:-0}" -lt 2048 ]]; then
	fatal "RSA_BITS must be >= 2048, got: $RSA_BITS" 1
fi

# Paths and files (respect env overrides)
# Compute XDG data directory default
default_xdg_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"

# Also compute CA data root (XDG-aware)
: "${CA_DATA_ROOT:=${default_xdg_data_dir}/simple-ca}"

# Default basePath to XDG location when not set
: "${basePath:=${CA_DATA_ROOT}}"

# If a CA is selected, scope to per-CA directories
if [[ -n "${CA_ID:-}" ]]; then
	caDir="${basePath}/cas/${CA_ID}"
	rootCAPath="${caDir}/root"
	intermediatePath="${caDir}/intermediate"
	# Scope export dir per CA below
fi

# Default paths when not set by CA scoping above
: "${rootCAPath:=${basePath}/root}"
: "${intermediatePath:=${basePath}/intermediate}"

# Default config files to script directory when not set (templates)
: "${rootConfig:=${SCRIPT_DIR}/openssl-root.cnf}"
: "${intermediateConfig:=${SCRIPT_DIR}/openssl-intermediate.cnf}"

# Default export directory to XDG location when not set; scope per CA if selected
: "${exportDir:=${default_xdg_data_dir}/simple-ca/export}"
if [[ -n "${CA_ID:-}" ]]; then
	exportDir="${exportDir}/${CA_ID}"
fi

rootCAKey="${rootCAPath}/private/ca.key.pem"
rootCaCert="${rootCAPath}/certs/ca.cert.pem"

intermediateKey="${intermediatePath}/private/intermediate.key.pem"
intermediateCsr="${intermediatePath}/csr/intermediate.csr.pem"
intermediateCert="${intermediatePath}/certs/intermediate.cert.pem"
certificateChain="${intermediatePath}/certs/ca-chain.cert.pem"

: "${SERVER_CN:=}"
serverKey="${intermediatePath}/private/${SERVER_CN}.key.pem"
serverCsr="${intermediatePath}/csr/${SERVER_CN}.csr"
serverCert="${intermediatePath}/certs/${SERVER_CN}.cert.pem"

outputDir="${basePath}/output/${SERVER_CN}"
serverPem="${outputDir}/${SERVER_CN}.pkcs8.key.pem"
serverPfx="${outputDir}/${SERVER_CN}.pfx"
rootCACertFriendly="${outputDir}/rootCA.crt.pem"

# Helper: require a CA to be selected for CA-dependent operations
require_ca_selected() {
	if [[ -z "${CA_ID:-}" ]]; then
		local def
		def=$(registry_get_default || true)
		if [[ -n "$def" ]]; then
			# Export for downstream scripts and recompute scoped paths
			export CA_ID="$def"
			# Recompute scoped directories now that CA_ID is set
			caDir="${basePath}/cas/${CA_ID}"
			rootCAPath="${caDir}/root"
			intermediatePath="${caDir}/intermediate"
			certificateChain="${intermediatePath}/certs/ca-chain.cert.pem"
			intermediateKey="${intermediatePath}/private/intermediate.key.pem"
			intermediateCsr="${intermediatePath}/csr/intermediate.csr.pem"
			intermediateCert="${intermediatePath}/certs/intermediate.cert.pem"
			rootCAKey="${rootCAPath}/private/ca.key.pem"
			rootCaCert="${rootCAPath}/certs/ca.cert.pem"
			exportDir="${default_xdg_data_dir}/simple-ca/export/${CA_ID}"
			return 0
		fi
		fatal "error: no CA selected. Use --ca <id> or set a default with 'simpleca use --ca <id>'" 2
	fi
}

# Helper: ensure per-CA working OpenSSL configs exist under the CA directories
ensure_per_ca_openssl_configs() {
	[[ -n "${CA_ID:-}" ]] || return 0
	local root_conf_run="${rootCAPath}/openssl-root.cnf"
	local inter_conf_run="${intermediatePath}/openssl-intermediate.cnf"
	mkdir -p "${rootCAPath}" "${intermediatePath}" || true
	if [[ ! -f "${root_conf_run}" && -f "${rootConfig}" ]]; then
		sed "s#^dir\s*=.*#dir               = ${rootCAPath}#" "${rootConfig}" > "${root_conf_run}"
	fi
	if [[ ! -f "${inter_conf_run}" && -f "${intermediateConfig}" ]]; then
		sed "s#^dir\s*=.*#dir               = ${intermediatePath}#" "${intermediateConfig}" > "${inter_conf_run}"
	fi
}
