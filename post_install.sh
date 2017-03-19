#!/bin/sh
#author: James zhang
#date: 17/03/2017
#description: automatically install *.rpm/deb in POST_DIR

INSTALL_PATH=/usr/sailing
distro=`uname -a | awk '{print $2}'`

if [ x"$distro" = x"centos" ]; then
        if [ ! -f .openssl-1.0.2d ]; then
		pushd  $INSTALL_PATH >/dev/null
		rpm -Uhv keyutils-libs-devel-1.5.8-3.el7.aarch64.rpm
		rpm -Uhv libcom_err-devel-1.42.9-9.el7.aarch64.rpm 
		rpm -Uhv libselinux-devel-2.5-6.el7.aarch64.rpm
		rpm -Uhv libverto-devel-0.2.5-4.el7.aarch64.rpm
		rpm -Uhv libsepol-devel-2.5-6.el7.aarch64.rpm
		rpm -Uhv pcre-devel-8.32-15.el7_2.1.aarch64.rpm
		rpm -Uhv libkadm5-1.14.1-27.el7_3.aarch64.rpm
                rpm -Uhv krb5-devel-1.14.1-27.el7_3.aarch64.rpm
                rpm -Uhv openssl*.rpm
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

