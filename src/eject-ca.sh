#!/bin/sh

. ./common.sh

if [ -d "$exportDir" ] && [ -x "$exportDir" ]; then
    echo "exporting ca to ca.tar.gz..."
    tar -zcf "${exportDir}/ca.tar.gz" "${basePath}"
    chmod 777 "${exportDir}/ca.tar.gz"
    echo "done..."
else
    echo "Export does not exist."
fi
