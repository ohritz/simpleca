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

print_import_usage() {
	cat <<'USAGE'
simpleca import - Restore CA from archive

Usage:
  simpleca import --ca-id <id> [options] [archive]

Options:
  --ca-id <id>               Identifier for the restored CA (required)
  -i, --input <file>         Archive file to restore from
  -f, --force                Overwrite existing CA
  -h, --help                 Show this help

Arguments:
  archive                    Archive file to restore from (if not using -i)

Examples:
  simpleca import --ca-id acme backup.tar.gz
  simpleca import --ca-id acme -i backup.tar.gz
  simpleca import --ca-id acme --force backup.tar.gz
USAGE
}

parse_import_opts() {
	FORCE=0; ARCHIVE_FILE=""; CA_NEW_ID=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				print_import_usage
				exit 0
				;;
			--ca-id)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					CA_NEW_ID="$2"
					shift 2
				else
					fatal "Missing argument for --ca-id" 2
				fi
				;;
			--ca-id=*)
				CA_NEW_ID="${1#--ca-id=}"
				shift
				;;
			-i|--input)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					ARCHIVE_FILE="$2"
					shift 2
				else
					fatal "Missing argument for --input" 2
				fi
				;;
			--input=*)
				ARCHIVE_FILE="${1#--input=}"
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

	# Handle positional argument for archive file
	if [[ -z "$ARCHIVE_FILE" ]] && [[ $# -gt 0 ]]; then
		ARCHIVE_FILE="$1"
		shift
	fi

	# Validate required arguments
	[[ -n "$CA_NEW_ID" ]] || fatal "--ca-id is required" 2
	[[ -n "$ARCHIVE_FILE" ]] || fatal "Archive file is required (use -i or positional argument)" 2

	# Validate CA id
	_validate_ca_id() {
		local id=${1:?}
		[[ "$id" =~ ^[a-z0-9][a-z0-9_-]{1,62}$ ]] || fatal "Invalid CA id: '$id' (allowed: [a-z0-9][a-z0-9_-]{1,62})" 2
	}
	_validate_ca_id "$CA_NEW_ID"

	# Ensure archive file has .tar.gz extension if not specified
	if [[ "$ARCHIVE_FILE" != *.tar.gz ]]; then
		ARCHIVE_FILE="${ARCHIVE_FILE}.tar.gz"
	fi

	# If the archive file is not an absolute path, check exportDir
	if [[ "$ARCHIVE_FILE" != /* ]] && [[ -f "${exportDir}/${ARCHIVE_FILE}" ]]; then
		ARCHIVE_FILE="${exportDir}/${ARCHIVE_FILE}"
	fi
}

run_import() {
	# Parse options
	parse_import_opts "$@"

	# Set CA scope for this import
	export CA_ID="$CA_NEW_ID"
	caDir="${basePath}/cas/${CA_ID}"
	exportDir="${exportDir%/}/${CA_ID}"

	# Create temporary directory early and set up cleanup
	local temp_dir
	temp_dir=$(mktemp -d)
	# Use a different cleanup approach that doesn't rely on variable scope
	trap 'rm -rf '"$temp_dir" EXIT

	# Check if archive file exists
	if [[ ! -f "$ARCHIVE_FILE" ]]; then
		fatal "Archive file not found: $ARCHIVE_FILE" 1
	fi

	# Check if CA already exists
	if [[ $FORCE -eq 0 ]] && [[ -d "$caDir" ]]; then
		fatal "CA '$CA_ID' already exists at $caDir. Use --force to overwrite." 1
	fi

	info "Restoring CA '$CA_ID' from: $ARCHIVE_FILE"

	# Extract archive
	if ! tar -zxf "$ARCHIVE_FILE" -C "$temp_dir" 2>/dev/null; then
		fatal "Failed to extract archive" 1
	fi

	# Find the CA directory in the archive
	local ca_dir_in_archive=""
	if [[ -d "$temp_dir/$CA_ID" ]]; then
		ca_dir_in_archive="$temp_dir/$CA_ID"
	elif [[ -d "$temp_dir/ca" ]]; then
		ca_dir_in_archive="$temp_dir/ca"
	else
		# Look for any directory that might be a CA
		for dir in "$temp_dir"/*; do
			if [[ -d "$dir" ]] && [[ -d "$dir/root" ]] && [[ -d "$dir/intermediate" ]]; then
				ca_dir_in_archive="$dir"
				break
			fi
		done
	fi

	if [[ -z "$ca_dir_in_archive" ]]; then
		fatal "No valid CA directory found in archive" 1
	fi

	# Remove existing CA directory if --force
	if [[ $FORCE -eq 1 ]] && [[ -d "$caDir" ]]; then
		rm -rf "$caDir"
	fi

	# Create parent directory and move CA
	mkdir -p "$(dirname "$caDir")"
	mv "$ca_dir_in_archive" "$caDir"

	# Restore registry info if present
	if [[ -f "$temp_dir/registry.json" ]]; then
		registry_register_ca "${CA_ID}" "${caDir}" "${exportDir}"
		info "✓ Registry updated"
	fi

	# Validate restored CA
	if [[ -f "${caDir}/root/certs/ca.cert.pem" ]] && [[ -f "${caDir}/intermediate/certs/intermediate.cert.pem" ]] && [[ -f "${caDir}/intermediate/certs/ca-chain.cert.pem" ]]; then
		info "✓ CA restored successfully"
		info "✓ CA files validated"
	else
		fatal "✗ CA restoration incomplete - missing required files" 1
	fi
}

# Run the import command
run_import "$@"
