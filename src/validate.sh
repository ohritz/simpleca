#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

print_validate_usage() {
	cat <<'USAGE'
simpleca validate - Validate certificates and chains

Usage:
  simpleca validate [options]

Options:
  -c, --cert <file>             Certificate file to validate (default: CA chain)
  -k, --key <file>              Private key file to validate
  -p, --pass-file <file>        Password file for private key
  -h, --help                    Show this help

Examples:
  simpleca validate
  simpleca validate --cert /path/to/cert.pem
  simpleca validate --cert cert.pem --key key.pem --pass-file pass.txt
USAGE
}

parse_validate_opts() {
	CERT_FILE=''; KEY_FILE=''; PASS_FILE=''

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				print_validate_usage
				exit 0
				;;
			-c|--cert)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					CERT_FILE="$2"
					shift 2
				else
					fatal "Missing argument for --cert" 2
				fi
				;;
			--cert=*)
				CERT_FILE="${1#--cert=}"
				shift
				;;
			-k|--key)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					KEY_FILE="$2"
					shift 2
				else
					fatal "Missing argument for --key" 2
				fi
				;;
			--key=*)
				KEY_FILE="${1#--key=}"
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

	# Set default certificate file if not specified
	if [[ -z "$CERT_FILE" ]]; then
		CERT_FILE="$certificateChain"
	fi

	# Validate files exist
	if [[ ! -f "$CERT_FILE" ]]; then
		fatal "Certificate file not found: $CERT_FILE" 2
	fi

	if [[ -n "$KEY_FILE" ]] && [[ ! -f "$KEY_FILE" ]]; then
		fatal "Private key file not found: $KEY_FILE" 2
	fi

	if [[ -n "$PASS_FILE" ]] && [[ ! -f "$PASS_FILE" ]]; then
		fatal "Password file not found: $PASS_FILE" 2
	fi
}

run_validate() {
	# Parse options
	parse_validate_opts "$@"

	info "Validating certificate: $CERT_FILE"

	# Validate certificate format and content
	if ! openssl x509 -in "$CERT_FILE" -text -noout >/dev/null 2>&1; then
		fatal "Invalid certificate format: $CERT_FILE" 1
	fi

	# Display certificate information
	info "Certificate details:"
	openssl x509 -in "$CERT_FILE" -text -noout | head -20

	# Validate certificate chain if it's a chain file
	if [[ "$CERT_FILE" == "$certificateChain" ]]; then
		info "Validating certificate chain..."
		if openssl verify -CAfile "$rootCaCert" "$intermediateCert" >/dev/null 2>&1; then
			info "✓ Certificate chain is valid"
		else
			fatal "✗ Certificate chain validation failed" 1
		fi
	fi

	# Validate private key if provided
	if [[ -n "$KEY_FILE" ]]; then
		info "Validating private key: $KEY_FILE"

		local pass_arg=""
		if [[ -n "$PASS_FILE" ]]; then
			pass_arg="-passin file:$PASS_FILE"
		fi

		if openssl pkey -in "$KEY_FILE" $pass_arg -noout >/dev/null 2>&1; then
			info "✓ Private key is valid"

			# Check if certificate and key match
			local cert_pubkey
			local key_pubkey

			cert_pubkey=$(openssl x509 -in "$CERT_FILE" -pubkey -noout 2>/dev/null | openssl pkey -pubin -outform PEM 2>/dev/null)
			key_pubkey=$(openssl pkey -in "$KEY_FILE" $pass_arg -pubout -outform PEM 2>/dev/null)

			if [[ "$cert_pubkey" == "$key_pubkey" ]]; then
				info "✓ Certificate and private key match"
			else
				fatal "✗ Certificate and private key do not match" 1
			fi
		else
			fatal "✗ Invalid private key: $KEY_FILE" 1
		fi
	fi

	info "Validation completed successfully"
}

# Run the validate command
run_validate "$@"
