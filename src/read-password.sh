#!/bin/sh

stty -echo
read passwd
stty echo
printf "\n"
echo $passwd
