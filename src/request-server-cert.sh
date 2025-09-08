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

print_issue_usage() {
	cat <<'USAGE'
simpleca issue - Issue a server certificate

Usage:
  simpleca issue [options]

Options:
  --ca <id>                     Select CA id (uses default from registry if omitted)
  -c, --cn <hostname>           Common Name (hostname) for the certificate
  -s, --sans <sans>             Subject Alternative Names (comma-separated)
  -k, --key-type <type>         Key type: ec (default) or rsa
  -r, --rsa-bits <bits>         RSA key size (default: 3072)
  -e, --ec-curve <curve>        EC curve: prime256v1 (default) or secp384r1
  -p, --pass-file <file>        Password file for non-interactive mode
  -d, --days <days>             Certificate validity in days (default: 398)
  -f, --force                   Overwrite existing certificate
  -h, --help                    Show this help

Examples:
  simpleca issue --cn api.local
  simpleca issue --ca acme --cn web.local --sans DNS:web.local,DNS:www.web.local
  simpleca issue --cn server.local --key-type rsa --rsa-bits 4096
  simpleca issue --cn app.local --pass-file /run/secrets/cert.pass
USAGE
}

parse_issue_opts() {
	# Don't reset variables - preserve environment defaults
	FORCE=0
	PASS_FILE=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				print_issue_usage
				exit 0
				;;
			--ca)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					export CA_ID="$2"
					shift 2
				else
					fatal "Missing argument for --ca" 2
				fi
				;;
			--ca=*)
				export CA_ID="${1#--ca=}"
				shift
				;;
			-c|--cn)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					SERVER_CN="$2"
					shift 2
				else
					fatal "Missing argument for --cn" 2
				fi
				;;
			--cn=*)
				SERVER_CN="${1#--cn=}"
				shift
				;;
			-s|--sans)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					SERVER_SANS="$2"
					shift 2
				else
					fatal "Missing argument for --sans" 2
				fi
				;;
			--sans=*)
				SERVER_SANS="${1#--sans=}"
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
			-d|--days)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					LEAF_DAYS="$2"
					shift 2
				else
					fatal "Missing argument for --days" 2
				fi
				;;
			--days=*)
				LEAF_DAYS="${1#--days=}"
				shift
				;;
			-f|--force)
				FORCE=1
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

	# Handle positional argument for backward compatibility
	if [[ $# -gt 0 ]] && [[ -z "$SERVER_CN" ]]; then
		SERVER_CN="$1"
		shift
	fi

	# Validate required arguments
	[[ -n "$SERVER_CN" ]] || fatal 'Missing required: --cn <hostname>' 2

	# Validate CA selection if specified
	if [[ -n "${CA_ID:-}" ]]; then
		# Check if CA exists (either in registry or on disk)
		if ! ca_exists "$CA_ID"; then
			fatal "CA '$CA_ID' not found. Use 'simpleca list' to see available CAs." 2
		fi
	fi

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

	# Validate days if specified
	if [[ -n "$LEAF_DAYS" ]]; then
		if [[ ! "$LEAF_DAYS" =~ ^[0-9]+$ ]] || [[ "$LEAF_DAYS" -lt 1 ]]; then
			fatal "LEAF_DAYS must be >= 1, got: $LEAF_DAYS" 2
		fi
	fi

	# Validate pass file if specified
	if [[ -n "$PASS_FILE" ]] && [[ ! -f "$PASS_FILE" ]]; then
		fatal "Password file not found: $PASS_FILE" 2
	fi

	# For multi-CA mode: use per-CA working configs if present; otherwise fallback to legacy dynamic configs
	if [[ -n "${CA_ID:-}" ]]; then
		ensure_per_ca_openssl_configs
		if [[ -f "${intermediatePath}/openssl-intermediate.cnf" ]]; then
			intermediateConfig="${intermediatePath}/openssl-intermediate.cnf"
		fi
		if [[ -f "${rootCAPath}/openssl-root.cnf" ]]; then
			rootConfig="${rootCAPath}/openssl-root.cnf"
		fi
	else
		# Legacy mode: use template configs but rewrite dir to current base paths if not default /opt/ca
		if [[ -f "${SCRIPT_DIR}/openssl-intermediate.cnf" ]]; then
			intermediateConfig="${SCRIPT_DIR}/openssl-intermediate.cnf"
		fi
		if [[ -f "${SCRIPT_DIR}/openssl-root.cnf" ]]; then
			rootConfig="${SCRIPT_DIR}/openssl-root.cnf"
		fi
		if [[ "$basePath" != "/opt/ca" ]]; then
			# Create dynamic intermediate config
			intermediate_conf_run=$(mktemp)
			sed "s|dir.*=.*/opt/ca/intermediate|dir = $intermediatePath|g" "$intermediateConfig" > "$intermediate_conf_run"
			intermediateConfig="$intermediate_conf_run"
			# Create dynamic root config if needed
			if [[ -f "$rootConfig" ]]; then
				root_conf_run=$(mktemp)
				sed "s|dir.*=.*/opt/ca/root|dir = $rootCAPath|g" "$rootConfig" > "$root_conf_run"
				rootConfig="$root_conf_run"
			fi
		fi
	fi

	# Update server-related variables now that SERVER_CN is set
	serverKey="${intermediatePath}/private/${SERVER_CN}.key.pem"
	serverCsr="${intermediatePath}/csr/${SERVER_CN}.csr"
	serverCert="${intermediatePath}/certs/${SERVER_CN}.cert.pem"
	outputDir="${basePath}/output/${SERVER_CN}"
	serverPem="${outputDir}/${SERVER_CN}.pkcs8.key.pem"
	serverPfx="${outputDir}/${SERVER_CN}.pfx"
}

run_issue() {
	# Parse options
	parse_issue_opts "$@"

	# Check if CA exists and is properly initialized
	if [[ ! -f "$intermediateKey" ]] || [[ ! -f "$intermediateCert" ]] || [[ ! -f "$certificateChain" ]]; then
		fatal "CA not found or not properly initialized. Run 'simpleca init --ca-id <id>' first." 1
	fi

	# Apply overrides if specified
	[[ -n "$KEY_TYPE" ]] && export KEY_TYPE
	[[ -n "$RSA_BITS" ]] && export RSA_BITS
	[[ -n "$EC_CURVE" ]] && export EC_CURVE
	[[ -n "$LEAF_DAYS" ]] && export LEAF_DAYS
	[[ -n "$SERVER_SANS" ]] && export SERVER_SANS

	export SERVER_CN

	# Check if certificate already exists
	if [[ $FORCE -eq 0 ]] && [[ -f "$serverCert" ]]; then
		fatal "Certificate already exists: $serverCert. Use --force to overwrite." 1
	fi

	info "Issuing certificate for: $SERVER_CN${CA_ID:+ (CA: ${CA_ID})}"

	#------------- Password prompts ------------------
	if [[ -n "$PASS_FILE" ]]; then
		# Non-interactive mode with password file
		rootCaPasswd="$(cat "$PASS_FILE")"
		passwd="$(cat "$PASS_FILE")"
	else
		# Interactive mode
		if [[ ${NON_INTERACTIVE:-0} -eq 1 ]]; then
			fatal "Non-interactive mode requires --pass-file" 1
		fi

		echo "Enter the intermediate CA password: "
					rootCaPasswd="$(read_password)"

			echo "Choose a password for the Server private key: "
			passwd="$(read_password)"
	fi
	#------------- --------------- ------------------

	# Output files
	# ${SERVER_CN}.key.pem: Server private key, password protected (this shouldn't be shared)
	# ${SERVER_CN}.csr: Server certificate signing request (this should be shared with the CA owner)
	# ${SERVER_CN}.cert.pem: Server certificate signed by the CA (this would be sent back by the CA owner) - keep on server
	# ${SERVER_CN}.pkcs8.key.pem: Conversion of server.key into a pkcs8 format gRPC likes (this shouldn't be shared)
	# ${SERVER_CN}.pfx: password protected pfx file with the whole certificate chain.

	# Step 1: Generate the Server Private Key (server.key)
	if [[ "$KEY_TYPE" == "ec" ]]; then
		openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:"${EC_CURVE}" \
			-pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:"${passwd}" \
			-out "$serverKey"
	else
		openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"${RSA_BITS}" \
			-aes-256-cbc -pass pass:"${passwd}" -out "$serverKey"
	fi
	chmod 400 "$serverKey"

	# Step 2: create a certificate signing request (server.csr)
	# Set default SANs if not provided
	if [[ -z "$SERVER_SANS" ]]; then
		SERVER_SANS="DNS:${SERVER_CN}"
	fi

	openssl req -config "$intermediateConfig" \
			-key "$serverKey" -passin pass:"$passwd" \
			-new -sha256 -out "$serverCsr" \
			-addext "subjectAltName = ${SERVER_SANS}" \
			-subj "/CN=${SERVER_CN}"

	# Step 3: Sign the certificate with the CA we created
	openssl ca -config "$intermediateConfig" \
			-extensions server_cert -days "${LEAF_DAYS}" -notext -md sha256 -batch \
			-passin pass:"$rootCaPasswd" \
			-in "$serverCsr" -out "$serverCert"
	chmod 444 "$serverCert"

	mkdir -p "$outputDir"

	# Step 4: Convert the server certificate to .pem format (server.pem) - usable by gRPC
	# First convert to unencrypted PKCS#8, then re-encrypt with modern format
	openssl pkcs8 -topk8 -nocrypt \
		-in "$serverKey" -passin pass:"$passwd" \
		-out "$serverPem.tmp"

	openssl pkcs8 -topk8 -v2 aes-256-cbc \
		-in "$serverPem.tmp" -out "$serverPem" \
		-passout pass:"${passwd}"

	rm -f "$serverPem.tmp"

	info "Exporting server cert as pkcs12/pfx file..."
	openssl pkcs12 -export -inkey "$serverKey" -passin pass:"${passwd}" \
			 -in "$serverCert" -certfile "$certificateChain" \
			 -out "$serverPfx" \
			 -keypbe AES-256-CBC -certpbe AES-256-CBC \
			 -macalg sha256 -iter "${PFX_ITER}" -maciter \
			 -passout pass:"${passwd}"

	info "Warning, the certificates will be copied to and possibly overwrite any files mounted to $exportDir"

	mkdir -p "$exportDir"
	cp "$outputDir"/* "$exportDir"/
	cp "$serverCert" "$exportDir"/
	cp "$certificateChain" "$exportDir"/
	chmod 776 "$exportDir"/*

	info "Certificate issued successfully for: $SERVER_CN${CA_ID:+ (CA: ${CA_ID})}"
	info "Files available in: $exportDir"
}

# Run the issue command
run_issue "$@"
