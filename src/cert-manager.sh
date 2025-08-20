#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

print_cert_manager_usage() {
	cat <<'USAGE'
simpleca cert-manager export - Export Kubernetes cert-manager CA Issuer artifacts

Usage:
  simpleca cert-manager export [options]

Options:
  -n, --ns|--namespace <name>   Kubernetes namespace (required)
      --issuer-name <name>      Issuer name (default: ca-issuer)
      --secret-name <name>      Secret name (default: ca-key-pair)
  -o, --out <dir>               Output base directory (default: /opt/export/manifests)
  -p, --pass-file <file>        Password file for intermediate key (non-interactive)
  -f, --force                   Overwrite files if they already exist
  -h, --help                    Show this help

Examples:
  simpleca cert-manager export --ns sandbox
  simpleca cert-manager export --ns prod --issuer-name corp-issuer --secret-name corp-ca --out /tmp/manifests
USAGE
}

parse_cert_manager_opts() {
	MODE=""; NAMESPACE=""; ISSUER_NAME="ca-issuer"; SECRET_NAME="ca-key-pair"; OUT_DIR="${exportDir:-/opt/export}/manifests"; FORCE=0; PASS_FILE=""

	# First positional must be 'export'
	if [[ $# -gt 0 ]]; then
		case "$1" in
			export) MODE="export"; shift;;
			--help|-h|help) print_cert_manager_usage; exit 0;;
			*) fatal "Unknown cert-manager subcommand: $1" 2;;
		esac
	else
		print_cert_manager_usage; exit 2
	fi

	while getopts ':n:o:p:fh-:' opt; do
		# Support GNU-style long options passed as separate arguments
		if [[ "$opt" = "-" && "$OPTARG" =~ ^(ns|namespace|issuer-name|secret-name|out|pass-file)$ ]]; then
			# OPTARG is the long option name without value; consume next arg as its value
			longopt="$OPTARG"; longval="$2"; shift 2 || true
			case "$longopt" in
				ns|namespace) NAMESPACE="$longval";;
				issuer-name) ISSUER_NAME="$longval";;
				secret-name) SECRET_NAME="$longval";;
				out) OUT_DIR="$longval";;
				pass-file) PASS_FILE="$longval";;
			esac
			continue
		fi
		case "$opt" in
			n) NAMESPACE="$OPTARG";;
			o) OUT_DIR="$OPTARG";;
			p) PASS_FILE="$OPTARG";;
			f) FORCE=1;;
			h) print_cert_manager_usage; exit 0;;
			-)
				case "$OPTARG" in
					ns=*) NAMESPACE="${OPTARG#ns=}";;
					namespace=*) NAMESPACE="${OPTARG#namespace=}";;
					issuer-name=*) ISSUER_NAME="${OPTARG#issuer-name=}";;
					secret-name=*) SECRET_NAME="${OPTARG#secret-name=}";;
					out=*) OUT_DIR="${OPTARG#out=}";;
					pass-file)
						PASS_FILE="$2"; shift 2; continue;;
					pass-file=*) PASS_FILE="${OPTARG#pass-file=}";;
					help) print_cert_manager_usage; exit 0;;
					*) fatal "Unknown option: --$OPTARG" 2;;
				esac;;
			:) fatal "Missing argument for -$OPTARG" 2;;
			\?) fatal "Unknown option: -$OPTARG" 2;;
		esac
	done
	shift $((OPTIND-1))

	[[ "$MODE" == "export" ]] || fatal "Missing subcommand: export" 2
	[[ -n "$NAMESPACE" ]] || fatal "Missing required: --ns|--namespace <name>" 2

	# Validate pass file if specified
	if [[ -n "$PASS_FILE" ]] && [[ ! -f "$PASS_FILE" ]]; then
		fatal "Password file not found: $PASS_FILE" 2
	fi
}

render_secret_yaml() {
	local outdir="$1"; local ns="$2"; local secret_name="$3"; local fullchain_file="$4"; local key_file="$5"
	local b64_crt b64_key
	b64_crt=$(base64 -w0 < "$fullchain_file")
	b64_key=$(base64 -w0 < "$key_file")
	cat > "${outdir}/secret.yaml" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${ns}
  labels:
    app.kubernetes.io/name: simpleca
type: kubernetes.io/tls
data:
  tls.crt: ${b64_crt}
  tls.key: ${b64_key}
YAML
}

render_issuer_yaml() {
	local outdir="$1"; local ns="$2"; local issuer_name="$3"; local secret_name="$4"
	cat > "${outdir}/issuer.yaml" <<YAML
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ${issuer_name}
  namespace: ${ns}
spec:
  ca:
    secretName: ${secret_name}
YAML
}

run_cert_manager() {
	parse_cert_manager_opts "$@"

	# Normalize OUT_DIR to a writable path; if /opt not writable, fallback to exportDir
	if ! mkdir -p "$OUT_DIR" 2>/dev/null; then
		OUT_DIR="${exportDir:-$OUT_DIR}"
		OUT_DIR="${OUT_DIR%/}/manifests"
		mkdir -p "$OUT_DIR"
	fi

	local dest_dir="${OUT_DIR%/}/${NAMESPACE}/${ISSUER_NAME}"
	mkdir -p "$dest_dir"

	# If files exist and not force, fail
	if [[ $FORCE -eq 0 ]]; then
		for f in "${dest_dir}/intermediate.key.unencrypted.pem" "${dest_dir}/issuer.fullchain.crt.pem" \
			"${dest_dir}/secret.yaml" "${dest_dir}/issuer.yaml"; do
			if [[ -f "$f" ]]; then
				fatal "File already exists: $f. Use --force to overwrite." 1
			fi
		done
	fi

	info "Exporting unencrypted intermediate key and manifests to: $dest_dir"
	info "Warning: an UNENCRYPTED private key will be written. Treat the output directory as sensitive."

	# Acquire intermediate key password
	local int_pass
	if [[ -n "$PASS_FILE" ]]; then
		int_pass="$(cat "$PASS_FILE")"
	else
		if [[ ${NON_INTERACTIVE:-0} -eq 1 ]]; then
			fatal "Non-interactive mode requires --pass-file to decrypt the intermediate key" 1
		fi
		echo "Enter the intermediate CA password: "
		int_pass="$(read_password)"
	fi

	# Write unencrypted PKCS#8 intermediate key to export dir ONLY
	local unenc_key_file="${dest_dir}/intermediate.key.unencrypted.pem"
	openssl pkey -in "$intermediateKey" -passin pass:"$int_pass" -out "$unenc_key_file"
	chmod 600 "$unenc_key_file"

	# Build full chain explicitly
	local fullchain_file="${dest_dir}/issuer.fullchain.crt.pem"
	cat "$intermediateCert" "$rootCaCert" > "$fullchain_file"
	chmod 644 "$fullchain_file"

	# Verify chain
	if openssl verify -CAfile "$rootCaCert" "$intermediateCert" >/dev/null 2>&1; then
		debug "Certificate chain validated"
	else
		fatal "Certificate chain validation failed" 1
	fi

	# Quick parse check for key
	if openssl pkey -in "$unenc_key_file" -noout >/dev/null 2>&1; then
		debug "Unencrypted intermediate key parses successfully"
	else
		fatal "Unencrypted intermediate key parse failed" 1
	fi

	# Render manifests
	render_secret_yaml "$dest_dir" "$NAMESPACE" "$SECRET_NAME" "$fullchain_file" "$unenc_key_file"
	render_issuer_yaml "$dest_dir" "$NAMESPACE" "$ISSUER_NAME" "$SECRET_NAME"

	# Optional YAML syntax check with yq if available
	if command -v yq >/dev/null 2>&1; then
		yq eval '.' "${dest_dir}/secret.yaml" >/dev/null
		yq eval '.' "${dest_dir}/issuer.yaml" >/dev/null
	fi

	info "Export complete. Files:"
	info "- ${unenc_key_file}"
	info "- ${fullchain_file}"
	info "- ${dest_dir}/secret.yaml"
	info "- ${dest_dir}/issuer.yaml"
}

# Execute
run_cert_manager "$@"
