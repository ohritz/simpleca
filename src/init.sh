#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"
. "${SCRIPT_DIR}/config.sh"

print_init_usage() {
	cat <<'USAGE'
simpleca init - Initialize root and intermediate CA

Usage:
  simpleca init [--ca-id <id>] [options]

Options:
  --ca-id <id>               Identifier for this CA (multi-CA mode)
  --env-file <file>          Source environment defaults from file before init
  -f, --force                Force re-initialization (overwrite existing CA)
  -k, --key-type <type>      Key type: ec (default) or rsa
  -r, --rsa-bits <bits>      RSA key size (default: 3072)
  -e, --ec-curve <curve>     EC curve: prime256v1 (default) or secp384r1
  -p, --pass-file <file>     Password file for non-interactive mode
  -h, --help                 Show this help

Examples:
  simpleca init
  simpleca init --ca-id acme --force
  simpleca init --key-type rsa --rsa-bits 4096
  simpleca init --ca-id acme --env-file ./inputs.env
USAGE
}

_validate_ca_id() {
	local id=${1:?}
	[[ "$id" =~ ^[a-z0-9][a-z0-9_-]{1,62}$ ]] || fatal "Invalid CA id: '$id' (allowed: [a-z0-9][a-z0-9_-]{1,62})" 2
}

parse_init_opts() {
	FORCE=0; KEY_TYPE="${KEY_TYPE:-}"; RSA_BITS="${RSA_BITS:-}"; EC_CURVE="${EC_CURVE:-}"; PASS_FILE="${PASS_FILE:-}"; CA_NEW_ID="${CA_NEW_ID:-}"; ENV_FILE=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help) print_init_usage; exit 0 ;;
			--env-file)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then ENV_FILE="$2"; shift 2; else fatal "Missing argument for --env-file" 2; fi ;;
			--env-file=*) ENV_FILE="${1#--env-file=}"; shift ;;
			--ca-id)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then CA_NEW_ID="$2"; shift 2; else fatal "Missing argument for --ca-id" 2; fi ;;
			--ca-id=*) CA_NEW_ID="${1#--ca-id=}"; shift ;;
			-f|--force) FORCE=1; shift ;;
			-k|--key-type)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then KEY_TYPE="$2"; shift 2; else fatal "Missing argument for --key-type" 2; fi ;;
			--key-type=*) KEY_TYPE="${1#--key-type=}"; shift ;;
			-r|--rsa-bits)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then RSA_BITS="$2"; shift 2; else fatal "Missing argument for --rsa-bits" 2; fi ;;
			--rsa-bits=*) RSA_BITS="${1#--rsa-bits=}"; shift ;;
			-e|--ec-curve)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then EC_CURVE="$2"; shift 2; else fatal "Missing argument for --ec-curve" 2; fi ;;
			--ec-curve=*) EC_CURVE="${1#--ec-curve=}"; shift ;;
			-p|--pass-file)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then PASS_FILE="$2"; shift 2; else fatal "Missing argument for --pass-file" 2; fi ;;
			--pass-file=*) PASS_FILE="${1#--pass-file=}"; shift ;;
			--) shift; break ;;
			-*) fatal "Unknown option: $1" 2 ;;
			*) break ;;
		esac
	done

	# Source env file early if provided
	if [[ -n "$ENV_FILE" ]]; then
		[[ -f "$ENV_FILE" ]] || fatal "--env-file not found: $ENV_FILE" 2
		load_dotenv "$ENV_FILE"
	fi

	# Validate CA id only if provided
	if [[ -n "$CA_NEW_ID" ]]; then
		_validate_ca_id "$CA_NEW_ID"
	fi
}

run_init() {
	# Parse options
	parse_init_opts "$@"

	# Apply overrides if specified
	[[ -n "$KEY_TYPE" ]] && export KEY_TYPE
	[[ -n "$RSA_BITS" ]] && export RSA_BITS
	[[ -n "$EC_CURVE" ]] && export EC_CURVE

	cwd=${PWD}

	if [[ -n "$CA_NEW_ID" ]]; then
		# -------- Multi-CA mode --------
		export CA_ID="$CA_NEW_ID"
		caDir="${basePath}/cas/${CA_ID}"
		rootCAPath="${caDir}/root"
		intermediatePath="${caDir}/intermediate"
		exportDir="${exportDir%/}/${CA_ID}"

		# Update path variables for the new CA
		rootCAKey="${rootCAPath}/private/ca.key.pem"
		rootCaCert="${rootCAPath}/certs/ca.cert.pem"
		intermediateKey="${intermediatePath}/private/intermediate.key.pem"
		intermediateCsr="${intermediatePath}/csr/intermediate.csr.pem"
		intermediateCert="${intermediatePath}/certs/intermediate.cert.pem"
		certificateChain="${intermediatePath}/certs/ca-chain.cert.pem"

		mkdir -p "$caDir" "$exportDir" || true

		# Check if CA already exists
		if [[ $FORCE -eq 0 ]] && ([[ -d "$caDir" ]] && [[ -e "${rootCAPath}/private/ca.key.pem" || -e "${intermediatePath}/private/intermediate.key.pem" ]]); then
			fatal "CA '$CA_ID' already exists at $caDir. Use --force to re-initialize." 1
		fi

		# Clean existing if --force
		if [[ $FORCE -eq 1 ]]; then
			rm -rf "$caDir"
		fi
		mkdir -p "$rootCAPath" "$intermediatePath"

		# Ensure directory structures
		cd "$rootCAPath"; mkdir -p certs crl newcerts private; chmod 700 private; touch index.txt; echo 1000 > serial; cd "$cwd"
		cd "$intermediatePath"; mkdir -p certs crl csr newcerts private; chmod 700 private; touch index.txt; echo 1000 > serial; echo 1000 > "$intermediatePath/crlnumber"; cd "$cwd"

		# Generate per-CA OpenSSL configs
		root_conf_run="$rootCAPath/openssl-root.cnf"
		intermediate_conf_run="$intermediatePath/openssl-intermediate.cnf"
		sed "s#^dir\s*=.*#dir               = $rootCAPath#" "$rootConfig" > "$root_conf_run"
		sed "s#^dir\s*=.*#dir               = $intermediatePath#" "$intermediateConfig" > "$intermediate_conf_run"

	else
		# -------- Legacy single-CA mode --------
		# Check if CA already exists
		if [[ $FORCE -eq 0 ]] && ([[ -f "$rootCAKey" ]] || [[ -f "$intermediateKey" ]]); then
			fatal "CA already exists. Use --force to re-initialize." 1
		fi

		# Remove and recreate directories to ensure clean state
		if [[ -d "$rootCAPath" ]]; then rm -rf "$rootCAPath"; fi
		if [[ -d "$intermediatePath" ]]; then rm -rf "$intermediatePath"; fi
		mkdir -p "$rootCAPath" "$intermediatePath"

		# Ensure directory structures
		cd "$rootCAPath"; mkdir -p certs crl newcerts private; chmod 700 private; touch index.txt; echo 1000 > serial; cd "$cwd"
		cd "$intermediatePath"; mkdir -p certs crl csr newcerts private; chmod 700 private; touch index.txt; echo 1000 > serial; echo 1000 > "$intermediatePath/crlnumber"; cd "$cwd"

		# Generate run-time OpenSSL configs pointing to these dirs
		root_conf_run="$rootCAPath/openssl-root.cnf"
		intermediate_conf_run="$intermediatePath/openssl-intermediate.cnf"
		sed "s#^dir\s*=.*#dir               = $rootCAPath#" "$rootConfig" > "$root_conf_run"
		sed "s#^dir\s*=.*#dir               = $intermediatePath#" "$intermediateConfig" > "$intermediate_conf_run"
	fi

	dd if=/dev/urandom of="${rootCAPath}/private/.rand" bs=256 count=1

	#------------- Password prompts ------------------
	if [[ -n "$PASS_FILE" ]]; then
		# Non-interactive mode with password file
		rootPasswd="$(cat "$PASS_FILE")"
		intermediatePasswd="$(cat "$PASS_FILE")"
	else
		# Interactive mode
		if [[ ${NON_INTERACTIVE:-0} -eq 1 ]]; then
			fatal "Non-interactive mode requires --pass-file" 1
		fi

		echo "Enter Root CA Password: "
		rootPasswd="$(read_password)"

		echo "Enter Intermediate CA Password: "
		intermediatePasswd="$(read_password)"
	fi
	#------------- --------------- ------------------

	info "Initializing CA '${CA_NEW_ID:-default}' with key type: ${KEY_TYPE:-ec}"

	# Generate root CA key using modern genpkey
	if [[ "$KEY_TYPE" == "ec" || -z "$KEY_TYPE" ]]; then
		openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:"${EC_CURVE:-prime256v1}" \
			-pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:"${rootPasswd}" \
			-out "$rootCAKey"
	else
		openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"${RSA_BITS:-3072}" \
			-aes-256-cbc -pass pass:"${rootPasswd}" -out "$rootCAKey"
	fi
	chmod 400 "$rootCAKey"

	openssl req -x509 -new -key "$rootCAKey" \
	  -config "$root_conf_run" -extensions v3_ca \
	  -sha256 -days 7300 -out "$rootCaCert" -passin pass:"${rootPasswd}" \
	  -subj "/C=${ROOT_COUNTRY}/ST=${ROOT_STATE}/L=${ROOT_LOCALITY}/O=${ROOT_ORG}/OU=${ROOT_ORG} Certificate Authority/CN=${ROOT_ORG} Root CA"
	chmod 444 "$rootCaCert"
	info "Root CA created"

	# Generate intermediate CA key
	if [[ "$KEY_TYPE" == "ec" || -z "$KEY_TYPE" ]]; then
		openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:"${EC_CURVE:-prime256v1}" \
			-pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:"${intermediatePasswd}" \
			-out "$intermediateKey"
	else
		openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"${RSA_BITS:-3072}" \
			-aes-256-cbc -pass pass:"${intermediatePasswd}" -out "$intermediateKey"
	fi
	chmod 400 "$intermediateKey"

	openssl req -config "$intermediate_conf_run" -new -sha256 \
		  -key "$intermediateKey" \
		  -out "$intermediateCsr" \
		  -passin pass:"${intermediatePasswd}" \
		  -subj "/C=${ROOT_COUNTRY}/ST=${ROOT_STATE}/L=${ROOT_LOCALITY}/O=${ROOT_ORG}/OU=${ROOT_ORG} Certificate Authority/CN=${ROOT_ORG} Intermediate CA"

	openssl ca -config "$root_conf_run" -extensions v3_intermediate_ca \
		  -days 3650 -notext -md sha256 -batch \
		  -in "$intermediateCsr" \
		  -passin pass:"${rootPasswd}" \
		  -out "$intermediateCert"
	chmod 444 "$intermediateCert"

	# Create certificate chain
	cat "$intermediateCert" "$rootCaCert" > "$certificateChain"
	chmod 444 "$certificateChain"
	info "Intermediate CA created"

	# In multi-CA mode, snapshot and register; legacy mode skips registry
	if [[ -n "$CA_NEW_ID" ]]; then
		mkdir -p "${caDir}/config"
		if [[ -n "$ENV_FILE" ]]; then
			cp "$ENV_FILE" "${caDir}/config/.env"
		fi
		created_at=$(date -Is)
		cat >"${caDir}/config/meta.json" <<EOF
{"id":"${CA_ID}","createdAt":"${created_at}","dataPath":"${caDir}"}
EOF
		registry_register_ca "${CA_ID}" "${caDir}" "${exportDir}"
	fi

	info "CA initialization complete${CA_NEW_ID:+ for '${CA_NEW_ID}'}"
}

# Run the init command
run_init "$@"
