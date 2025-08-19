#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

print_issue_usage() {
	cat <<'USAGE'
simpleca issue - Issue a server certificate

Usage:
  simpleca issue [options]

Options:
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
  simpleca issue --cn web.local --sans DNS:web.local,DNS:www.web.local
  simpleca issue --cn server.local --key-type rsa --rsa-bits 4096
  simpleca issue --cn app.local --pass-file /run/secrets/cert.pass
USAGE
}

parse_issue_opts() {
	SERVER_CN=''; SERVER_SANS=''; KEY_TYPE=''; RSA_BITS=''; EC_CURVE=''; PASS_FILE=''; LEAF_DAYS=''; FORCE=0

	while getopts ':c:s:k:r:e:p:d:fh-:' opt; do
		case "$opt" in
			c) SERVER_CN="$OPTARG";;
			s) SERVER_SANS="$OPTARG";;
			k) KEY_TYPE="$OPTARG";;
			r) RSA_BITS="$OPTARG";;
			e) EC_CURVE="$OPTARG";;
			p) PASS_FILE="$OPTARG";;
			d) LEAF_DAYS="$OPTARG";;
			f) FORCE=1;;
			h) print_issue_usage; exit 0;;
			-)
				case "$OPTARG" in
					cn=*) SERVER_CN="${OPTARG#cn=}";;
					sans=*) SERVER_SANS="${OPTARG#sans=}";;
					key-type=*) KEY_TYPE="${OPTARG#key-type=}";;
					rsa-bits=*) RSA_BITS="${OPTARG#rsa-bits=}";;
					ec-curve=*) EC_CURVE="${OPTARG#ec-curve=}";;
					pass-file=*) PASS_FILE="${OPTARG#pass-file=}";;
					days=*) LEAF_DAYS="${OPTARG#days=}";;
					force) FORCE=1;;
					help) print_issue_usage; exit 0;;
					*) fatal "Unknown option: --$OPTARG" 2;;
				esac;;
			:) fatal "Missing argument for -$OPTARG" 2;;
			\?) fatal "Unknown option: -$OPTARG" 2;;
		esac
	done
	shift $((OPTIND-1))

	# Handle positional argument for backward compatibility
	if [[ $# -gt 0 ]] && [[ -z "$SERVER_CN" ]]; then
		SERVER_CN="$1"
		shift
	fi

	# Validate required arguments
	[[ -n "$SERVER_CN" ]] || fatal 'Missing required: --cn <hostname>' 2

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
		if [[ ! "$LEAF_DAYS" =~ ^[0-9]+$ ]] || [[ "$LEAF_DAYS" -lt 1 ]] || [[ "$LEAF_DAYS" -gt 825 ]]; then
			fatal "LEAF_DAYS must be between 1 and 825, got: $LEAF_DAYS" 2
		fi
	fi

	# Validate pass file if specified
	if [[ -n "$PASS_FILE" ]] && [[ ! -f "$PASS_FILE" ]]; then
		fatal "Password file not found: $PASS_FILE" 2
	fi
}

run_issue() {
	# Parse options
	parse_issue_opts "$@"

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

	info "Issuing certificate for: $SERVER_CN"

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
		rootCaPasswd="$(. /opt/tools/read-password.sh)"

		echo "Choose a password for the Server private key: "
		passwd="$(. /opt/tools/read-password.sh)"
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

	# Step 3: Sign the certificate with the CA we created (it's called self signing) - server.crt
	openssl ca -config "$intermediateConfig" \
			-extensions server_cert -days "${LEAF_DAYS}" -notext -md sha256 -batch \
			-passin pass:"$rootCaPasswd" \
			-in "$serverCsr" -out "$serverCert"
	chmod 444 "$serverCert"

	mkdir -p "$outputDir"

	# Step 4: Convert the server certificate to .pem format (server.pem) - usable by gRPC
	openssl pkcs8 -topk8 -v2 aes-256-cbc -iter "${PKCS8_ITER}" \
		-passin pass:"$passwd" -passout pass:"${passwd}" \
		-in "$serverKey" -out "$serverPem"

	info "Exporting server cert as pkcs12/pfx file..."
	openssl pkcs12 -export -inkey "$serverKey" -passin pass:"${passwd}" \
				 -in "$serverCert" -certfile "$certificateChain" \
				 -out "$serverPfx" \
				 -keypbe AES-256-CBC -certpbe AES-256-CBC \
				 -macalg sha256 -iter "${PFX_ITER}" -maciter

	info "Warning, the certificates will be copied to and possibly overwrite any files mounted to $exportDir"

	cp "$outputDir"/* "$exportDir"/
	cp "$serverCert" "$exportDir"/
	cp "$certificateChain" "$exportDir"/
	chmod 776 "$exportDir"/*

	info "Certificate issued successfully for: $SERVER_CN"
	info "Files available in: $exportDir"
}

# Run the issue command
run_issue "$@"
