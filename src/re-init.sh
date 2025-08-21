#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

print_reinit_usage() {
	cat <<'USAGE'
simpleca re-init - Restore CA from archive

Usage:
  simpleca re-init [options] [archive]

Options:
  -f, --force                   Overwrite existing CA
  -h, --help                    Show this help

Arguments:
  archive                       Archive file to restore from (default: ca.tar.gz)

Examples:
  simpleca re-init
  simpleca re-init backup.tar.gz
  simpleca re-init --force ca-backup.tar.gz
USAGE
}

parse_reinit_opts() {
	FORCE=0; ARCHIVE_FILE="ca.tar.gz"

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				print_reinit_usage
				exit 0
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
	if [[ $# -gt 0 ]]; then
		ARCHIVE_FILE="$1"
		shift
	fi

	# Ensure archive file has .tar.gz extension if not specified
	if [[ "$ARCHIVE_FILE" != *.tar.gz ]]; then
		ARCHIVE_FILE="${ARCHIVE_FILE}.tar.gz"
	fi

	# If the archive file is not an absolute path, prepend exportDir
	if [[ "$ARCHIVE_FILE" != /* ]]; then
		ARCHIVE_FILE="${exportDir}/${ARCHIVE_FILE}"
	fi
}

run_reinit() {
	# Parse options
	parse_reinit_opts "$@"

	# Check if export directory exists
	if [[ ! -d "$exportDir" ]] || [[ ! -r "$exportDir" ]]; then
		fatal "Export directory not accessible: $exportDir" 1
	fi

	# Check if archive file exists
	if [[ ! -f "$ARCHIVE_FILE" ]]; then
		fatal "Archive file not found: $ARCHIVE_FILE" 1
	fi

	# Check if CA already exists
	if [[ $FORCE -eq 0 ]] && ([[ -d "$rootCAPath" ]] || [[ -d "$intermediatePath" ]]); then
		fatal "CA already exists. Use --force to overwrite." 1
	fi

	info "Restoring CA from: $ARCHIVE_FILE"

	# Extract archive
	if tar -zxf "$ARCHIVE_FILE" -C "$(dirname "$basePath")" 2>/dev/null; then
		info "✓ CA restored successfully"

		# Validate restored CA
		if [[ -f "$rootCaCert" ]] && [[ -f "$intermediateCert" ]] && [[ -f "$certificateChain" ]]; then
			info "✓ CA files validated"
		else
			fatal "✗ CA restoration incomplete - missing required files" 1
		fi
	else
		fatal "Failed to restore CA from archive" 1
	fi
}

# Run the re-init command
run_reinit "$@"
