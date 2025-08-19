#!/usr/bin/env bash
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first (only if not already sourced)
if [[ -z "${_UTILS_SOURCED:-}" ]]; then
	. "${SCRIPT_DIR}/utils.sh"
	setup_error_handling
	_UTILS_SOURCED=1
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
if [[ "$KEY_TYPE" == "rsa" ]] && [[ "$RSA_BITS" -lt 2048 ]]; then
	fatal "RSA_BITS must be >= 2048, got: $RSA_BITS" 1
fi

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
