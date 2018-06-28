#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

UPTODATE=

if [ $OS = "Ubuntu" ] && [ $VER = "16.04" ]; then
    apt-get update -qq
    apt-get install docker.io git
    UPTODATE=1
fi

if [ -z "${UPTODATE}" ]; then
    echo "OS not handled by this script.  Check dependencies manually"
fi
