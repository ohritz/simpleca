#!/bin/sh

arg=${1:?"Argument must be either --init, --eject or hostname"}
echo 
shift
case $arg in
    --init)
        echo "Initial Setup of the ca"
        . ./init.sh
        ;;
    --eject)
        echo "Ejecting the ca"
        . ./eject-ca.sh
        ;;
    --re-init)
        echo "Recreating from tar"
        . ./re-init.sh $1
        ;;
    *)   
        echo "Making request for hostname $arg"
        . ./request-server-cert.sh "$arg"
        ;;
esac

