#!/bin/sh
#author: James zhang
#date: 17/03/2017
#description: automatically install *.rpm/deb in POST_DIR

INSTALL_PATH=/usr/sailing
distro=`uname -a | awk '{print $2}'`

if [ x"$distro" = x"centos" ]; then
	pushd  $INSTALL_PATH >/dev/null
	if [ ! -f .openssl-1.0.2d ]; then
                rpm -Uhv *.rpm
                touch .openssl-1.0.2d
        fi
	popd > /dev/null
elif  [ x"$distro" = x"ubuntu" ]; then
        if [ ! -f ${INSTALL_PATH}/.openssl-1.0.2g ]; then
                dpkg -i  ${INSTALL_PATH}/*.deb
                touch    ${INSTALL_PATH}/.openssl-1.0.2g
        fi
else
        echo "Unknow Distro type!" >&2 ; exit 1
fi

