#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling
. "${SCRIPT_DIR}/common.sh"
. "${SCRIPT_DIR}/config.sh"

print_list_usage() {
	cat <<'USAGE'
simpleca list - List registered CAs

Usage:
  simpleca list
USAGE
}

run_list() {
	registry_list | awk 'BEGIN{FS="\t"; printf("%s\t%-40s\t%s\n","ID","DATA PATH","DEFAULT"); printf("%s\n", "================================================================================");}{printf("%s\t%-40s\t%s\n",$1,$2,$3)}'
}

run_list "$@"
