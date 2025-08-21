#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

print_init_usage() {
	cat <<'USAGE'
simpleca init - Initialize root and intermediate CA

Usage:
  simpleca init [options]

Options:
  -f, --force                   Force re-initialization (overwrite existing CA)
  -k, --key-type <type>         Key type: ec (default) or rsa
  -r, --rsa-bits <bits>         RSA key size (default: 3072)
  -e, --ec-curve <curve>        EC curve: prime256v1 (default) or secp384r1
  -p, --pass-file <file>        Password file for non-interactive mode
  -h, --help                    Show this help

Examples:
  simpleca init
  simpleca init --force
  simpleca init --key-type rsa --rsa-bits 4096
  simpleca init --pass-file /run/secrets/ca.pass
USAGE
}

parse_init_opts() {
	FORCE=0; KEY_TYPE="${KEY_TYPE:-}"; RSA_BITS="${RSA_BITS:-}"; EC_CURVE="${EC_CURVE:-}"; PASS_FILE="${PASS_FILE:-}"

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				print_init_usage
				exit 0
				;;
			-f|--force)
				FORCE=1
				shift
				;;
			-k|--key-type)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					KEY_TYPE="$2"
					shift 2
				else
					fatal "Missing argument for --key-type" 2
				fi
				;;
			--key-type=*)
				KEY_TYPE="${1#--key-type=}"
				shift
				;;
			-r|--rsa-bits)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					RSA_BITS="$2"
					shift 2
				else
					fatal "Missing argument for --rsa-bits" 2
				fi
				;;
			--rsa-bits=*)
				RSA_BITS="${1#--rsa-bits=}"
				shift
				;;
			-e|--ec-curve)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					EC_CURVE="$2"
					shift 2
				else
					fatal "Missing argument for --ec-curve" 2
				fi
				;;
			--ec-curve=*)
				EC_CURVE="${1#--ec-curve=}"
				shift
				;;
			-p|--pass-file)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					PASS_FILE="$2"
					shift 2
				else
					fatal "Missing argument for --pass-file" 2
				fi
				;;
			--pass-file=*)
				PASS_FILE="${1#--pass-file=}"
				shift
				;;
			--)
				shift
				break
				;;
			-*)
				fatal "Unknown option: $1" 2
				;;
			*)
				break
				;;
		esac
	done

	# Validate key type if specified
	if [[ -n "$KEY_TYPE" ]]; then
		case "$KEY_TYPE" in
			ec|rsa) ;;
			*) fatal "Invalid KEY_TYPE: $KEY_TYPE. Must be 'ec' or 'rsa'" 2 ;;
		esac
	fi

	# Validate EC curve if specified
	if [[ -n "$EC_CURVE" ]]; then
		case "$EC_CURVE" in
			prime256v1|secp384r1) ;;
			*) fatal "Invalid EC_CURVE: $EC_CURVE. Must be 'prime256v1' or 'secp384r1'" 2 ;;
		esac
	fi

	# Validate RSA bits if specified
	if [[ -n "$RSA_BITS" ]]; then
		if [[ ! "$RSA_BITS" =~ ^[0-9]+$ ]] || [[ "$RSA_BITS" -lt 2048 ]]; then
			fatal "RSA_BITS must be >= 2048, got: $RSA_BITS" 2
		fi
	fi

	# Validate pass file if specified
	if [[ -n "$PASS_FILE" ]] && [[ ! -f "$PASS_FILE" ]]; then
		fatal "Password file not found: $PASS_FILE" 2
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

	# Check if CA already exists
	if [[ $FORCE -eq 0 ]] && ([[ -f "$rootCAKey" ]] || [[ -f "$intermediateKey" ]]); then
		fatal "CA already exists. Use --force to re-initialize." 1
	fi

	# Ensure defaults if not provided
	[[ -z "$KEY_TYPE" ]] && KEY_TYPE="ec"
	[[ -z "$EC_CURVE" ]] && EC_CURVE="prime256v1"
	[[ -z "$RSA_BITS" ]] && RSA_BITS="3072"
	info "Initializing CA with key type: $KEY_TYPE"
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

	# ------------------ Create root CA --------------------------
	info "Creating root CA key cert pair."

	if [[ -d "$rootCAPath" ]]; then
		info "root cert directories found... removing & recreating"
		rm -rf "$rootCAPath"
	fi
	mkdir -p "$rootCAPath"

	if [[ -d "$intermediatePath" ]]; then
		info "intermediate cert directories found... removing & recreating"
		rm -rf "$intermediatePath"
	fi
	mkdir -p "$intermediatePath"

	cd "$rootCAPath"
	mkdir certs crl newcerts private
	chmod 700 private
	touch index.txt
	echo 1000 > serial
	cd "$cwd"

	# Generate per-run OpenSSL config files with correct directories
	root_conf_run="$rootCAPath/openssl-root.cnf"
	intermediate_conf_run="$intermediatePath/openssl-intermediate.cnf"
	sed "s#^dir\s*=.*#dir               = $rootCAPath#" "$rootConfig" > "$root_conf_run"

	dd if=/dev/urandom of="${rootCAPath}/private/.rand" bs=256 count=1

	# Output files
	# # ca.key.pem: Certificate Authority private key file (this shouldn't be shared in real-life)
	# # ca.cert.pem: Certificate Authority trust certificate (this should be shared with users in real-life)

	# Generate root CA key using modern genpkey
	if [[ "$KEY_TYPE" == "ec" ]]; then
		openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:"${EC_CURVE}" \
			-pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:"${rootPasswd}" \
			-out "$rootCAKey"
	else
		openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"${RSA_BITS}" \
			-aes-256-cbc -pass pass:"${rootPasswd}" -out "$rootCAKey"
	fi
	chmod 400 "$rootCAKey"

	openssl req -x509 -new -key "$rootCAKey" \
	  -config "$root_conf_run" -extensions v3_ca \
	  -sha256 -days 7300 -out "$rootCaCert" -passin pass:"${rootPasswd}" \
	  -subj "/C=${ROOT_COUNTRY}/ST=${ROOT_STATE}/L=${ROOT_LOCALITY}/O=${ROOT_ORG}/OU=${ROOT_ORG} Certificate Authority/CN=${ROOT_ORG} Root CA"

	chmod 444 "$rootCaCert"
	info "Root CA created"

	# ------------------ Create intermediate CA --------------------------

	cd "$intermediatePath"
	mkdir certs crl csr newcerts private
	chmod 700 private
	touch index.txt
	echo 1000 > serial
	echo 1000 > "$intermediatePath/crlnumber"
	cd "$cwd"

	info "Creating intermediate CA"

	# Generate per-run intermediate config with correct directory
	sed "s#^dir\s*=.*#dir               = $intermediatePath#" "$intermediateConfig" > "$intermediate_conf_run"

	# Generate intermediate CA key using modern genpkey
	if [[ "$KEY_TYPE" == "ec" ]]; then
		openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:"${EC_CURVE}" \
			-pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:"${intermediatePasswd}" \
			-out "$intermediateKey"
	else
		openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"${RSA_BITS}" \
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
	info "CA initialization complete"
}

# Run the init command
run_init "$@"
