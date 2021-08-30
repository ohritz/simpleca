#!/bin/sh

. ./common.sh

fileName=${1:-"ca.tar.gz"}

if [ -d "$exportDir" ] && [ -x "$exportDir" ]; then
    echo "importing ca from ${fileName}..."
    cd /
    tar -zvxf "${exportDir}/${fileName}" -C /
    echo "done..."
else
    echo "Export does not exist."
fi
