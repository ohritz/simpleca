#!/usr/bin/env bash
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"

if [ -d "$exportDir" ] && [ -x "$exportDir" ]; then
    echo "exporting ca to ca.tar.gz..."
    tar -zcf "${exportDir}/ca.tar.gz" "${basePath}"
    chmod 777 "${exportDir}/ca.tar.gz"
    echo "done..."
else
    echo "Export does not exist."
fi
