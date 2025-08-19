#!/usr/bin/env bash
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

fileName=${1:-"ca.tar.gz"}

if [ -d "$exportDir" ] && [ -x "$exportDir" ]; then
    echo "importing ca from ${fileName}..."
    cd /
    tar -zvxf "${exportDir}/${fileName}" -C /
    echo "done..."
else
    echo "Export does not exist."
fi
