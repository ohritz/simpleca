#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

print_eject_usage() {
	cat <<'USAGE'
simpleca eject - Archive current CA state

Usage:
  simpleca eject [options]

Options:
  -o, --output <file>           Output archive file (default: ca.tar.gz)
  -f, --force                   Overwrite existing archive
  -h, --help                    Show this help

Examples:
  simpleca eject
  simpleca eject --output backup.tar.gz
  simpleca eject --force
USAGE
}

parse_eject_opts() {
	OUTPUT_FILE="ca.tar.gz"; FORCE=0

	while getopts ':o:fh-:' opt; do
		case "$opt" in
			o) OUTPUT_FILE="$OPTARG";;
			f) FORCE=1;;
			h) print_eject_usage; exit 0;;
			-)
				case "$OPTARG" in
					output=*) OUTPUT_FILE="${OPTARG#output=}";;
					force) FORCE=1;;
					help) print_eject_usage; exit 0;;
					*) fatal "Unknown option: --$OPTARG" 2;;
				esac;;
			:) fatal "Missing argument for -$OPTARG" 2;;
			\?) fatal "Unknown option: -$OPTARG" 2;;
		esac
	done
	shift $((OPTIND-1))

	# Ensure output file has .tar.gz extension if not specified
	if [[ "$OUTPUT_FILE" != *.tar.gz ]]; then
		OUTPUT_FILE="${OUTPUT_FILE}.tar.gz"
	fi

	# Set full path to export directory
	OUTPUT_FILE="${exportDir}/${OUTPUT_FILE}"
}

run_eject() {
	# Parse options
	parse_eject_opts "$@"

	# Check if CA exists
	if [[ ! -d "$basePath" ]]; then
		fatal "CA not found. Run 'simpleca init' first." 1
	fi

	# Check if export directory exists
	if [[ ! -d "$exportDir" ]] || [[ ! -w "$exportDir" ]]; then
		fatal "Export directory not accessible: $exportDir" 1
	fi

	# Check if output file already exists
	if [[ -f "$OUTPUT_FILE" ]] && [[ $FORCE -eq 0 ]]; then
		fatal "Archive already exists: $OUTPUT_FILE. Use --force to overwrite." 1
	fi

	info "Archiving CA to: $OUTPUT_FILE"

	# Create archive
	if tar -zcf "$OUTPUT_FILE" -C "$(dirname "$basePath")" "$(basename "$basePath")" 2>/dev/null; then
		chmod 644 "$OUTPUT_FILE"
		info "✓ CA archived successfully"
		info "Archive size: $(du -h "$OUTPUT_FILE" | cut -f1)"
	else
		fatal "Failed to create archive" 1
	fi
}

# Run the eject command
run_eject "$@"
