#!/bin/sh
#author: James zhang
#date: 17/03/2017
#description: automatically install *.rpm/deb in POST_DIR

INSTALL_PATH=/usr/sailing
distro=`uname -a | awk '{print $2}'`

if [ x"$distro" = x"centos" ]; then
        if [ ! -f .openssl-1.0.2d ]; then
		pushd  $INSTALL_PATH >/dev/null
                rpm -Uhv *.rpm
                touch .openssl-1.0.2d
		popd > /dev/null
        fi
elif  [ x"$distro" = x"ubuntu" ]; then
        if [ ! -f .openssl-1.0.2g ]; then
		/bin/bash pushd  $INSTALL_PATH >/dev/null
                dpkg -i  *.deb
                touch .openssl-1.0.2g
		/bin/bash popd >/dev/null
        fi
else
        echo "Unknow Distro type!" >&2 ; exit 1
fi

