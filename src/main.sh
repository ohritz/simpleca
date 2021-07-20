#!/bin/sh

arg=${1:?"Argument must be either --init or hostname"}

echo 

if [[ $arg == "--init" ]]; then
    echo "Initial Setup of the ca"
    . ./init.sh
else     
    echo "Making request for hostname $arg"
    . ./request-server-cert.sh "$arg"
fi
