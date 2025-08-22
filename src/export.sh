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

print_export_usage() {
	cat <<'USAGE'
simpleca export - Archive CA state

Usage:
  simpleca export [options]

Options:
  -o, --output <file>           Output archive file (default: auto-generated)
  -f, --force                   Overwrite existing archive
  -h, --help                    Show this help

Examples:
  simpleca export
  simpleca export --output backup.tar.gz
  simpleca export --force
USAGE
}

parse_export_opts() {
	OUTPUT_FILE=""; FORCE=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				print_export_usage
				exit 0
				;;
			-o|--output)
				if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
					OUTPUT_FILE="$2"
					shift 2
				else
					fatal "Missing argument for --output" 2
				fi
				;;
			--output=*)
				OUTPUT_FILE="${1#--output=}"
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

	# CA must be selected for export
	require_ca_selected
}

run_export() {
	# Parse options
	parse_export_opts "$@"

	# Create temporary directory early and set up cleanup
	local temp_dir
	temp_dir=$(mktemp -d)
	# Use a different cleanup approach that doesn't rely on variable scope
	trap 'rm -rf '"$temp_dir" EXIT

	# Generate default output filename if not specified
	if [[ -z "$OUTPUT_FILE" ]]; then
		local timestamp
		timestamp=$(date +%Y%m%d%H%M%S)
		OUTPUT_FILE="${exportDir}/${CA_ID}-${timestamp}.tar.gz"
	fi

	# Ensure output file has .tar.gz extension if not specified
	if [[ "$OUTPUT_FILE" != *.tar.gz ]]; then
		OUTPUT_FILE="${OUTPUT_FILE}.tar.gz"
	fi

	# If the output file is not an absolute path, prepend exportDir
	if [[ "$OUTPUT_FILE" != /* ]]; then
		OUTPUT_FILE="${exportDir}/${OUTPUT_FILE}"
	fi

	# Check if CA exists
	if [[ ! -d "$caDir" ]]; then
		fatal "CA directory not found: $caDir" 1
	fi

	# Check if export directory exists and is writable
	if [[ ! -d "$(dirname "$OUTPUT_FILE")" ]] || [[ ! -w "$(dirname "$OUTPUT_FILE")" ]]; then
		fatal "Export directory not accessible: $(dirname "$OUTPUT_FILE")" 1
	fi

	# Check if output file already exists
	if [[ -f "$OUTPUT_FILE" ]] && [[ $FORCE -eq 0 ]]; then
		fatal "Archive already exists: $OUTPUT_FILE. Use --force to overwrite." 1
	fi

	info "Archiving CA '${CA_ID}' to: $OUTPUT_FILE"

	# Copy CA directory
	cp -r "$caDir" "$temp_dir/"

	# Include registry info if available
	if [[ -f "${REGISTRY_PATH}" ]]; then
		cp "${REGISTRY_PATH}" "$temp_dir/registry.json"
	fi

	# Create archive
	if tar -zcf "$OUTPUT_FILE" -C "$temp_dir" . 2>/dev/null; then
		chmod 644 "$OUTPUT_FILE"
		info "✓ CA archived successfully"
		info "Archive size: $(du -h "$OUTPUT_FILE" | cut -f1)"
	else
		fatal "Failed to create archive" 1
	fi
}

# Run the export command
run_export "$@"
