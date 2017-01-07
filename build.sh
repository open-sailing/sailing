#!/bin/bash
###################################################################################
# ./sailing/build.sh --help
# ./sailing/build.sh --builddir=./workspace
# ./sailing/build.sh --builddir=./workspace --mac=01-00-18-82-05-00-7f,01-00-18-82-05-00-68 \
# 					 --deploy=usb:/dev/sdb --deploy=iso  --deploy=pxe
###################################################################################

###################################################################################
# Global Variables
###################################################################################
ARCH=arm64
PLATFORMS=D05	
CAPACITY=50GB
DISTROS=CentOS 
OUTPUT_DIR=workspace
CROSS_COMPILE=aarch64-linux-gnu-
ESTUARY_TE_CONFIG=estuary_te_defconfig
CORE_NUM=`cat /proc/cpuinfo | grep "processor" | wc -l`
DOWNLOAD_FTP_ADDR=http://open-estuary.org/download/AllDownloads/FolderNotVisibleOnWebsite/EstuaryInternalConfig
CHINA_INTERAL_FTP_ADDR=ftp://117.78.41.188/FolderNotVisibleOnWebsite/EstuaryInternalConfig
SAILING_CFGFILE=sailing-config.xml

###################################################################################
# Const Variables, PATH
###################################################################################
CURDIR=`pwd`
TOPDIR=$(cd `dirname $0` ; pwd)
if [ x"$CURDIR" = x"$TOPDIR" ]; then
	echo "---------------------------------------------------------------"
	echo "- Please execute build.sh in open-sailing project root directory!"
	echo "- Example:"
	echo "-     ./open-sailing/build.sh --deploy=iso --builddir=./workspace"
	echo "---------------------------------------------------------------"
	exit 1
fi

export LANG=C
export LC_ALL=C
export PATH=$TOPDIR:$TOPDIR/include:$TOPDIR/submodules:$TOPDIR/deploy:$PATH


TOOLCHAIN_DIR= # Toolchain director

###################################################################################
# Usage
###################################################################################
Usage()
{
cat << EOF
Usage: ./sailing/build.sh [options]
Options:
	-h, --help: Display this information
	-v, --version: print estuary version
Options:
	--builddir: Build output directory, default is workspace
	--mac: target board mac address, --mac must be specified if deploy type is pxe

	-a: download address, China or Estuary(default Estuary)	
	
Example:
	./sailing/build.sh --help
	./sailing/build.sh --builddir=./workspace \\
		--deploy=pxe --mac=01-00-18-82-05-00-7f,01-00-18-82-05-00-68 \\
		--deploy=usb:/dev/sdb --deploy=iso
	
	
EOF
}

###################################################################################
# string[] get_field_content <xml_file> <field>
###################################################################################
get_field_content()
{
	local xml_file=$1
	local field=$2
	local xml_content=(`sed -n "/<$field>/,/<\/$field>/p" $xml_file 2>/dev/null | sed -e '/^$/d' | sed 's/ //g'`)
	unset xml_content[0]
	unset xml_content[${#xml_content[@]}]
	echo ${xml_content[*]}
}

###################################################################################
# check_sum <target_dir> <checksum_source>
###################################################################################
check_sum()
{
	(
	target_dir=$1
	checksum_source=$2
	checksum_dir=$(cd `dirname $checksum_source` ; pwd)
	checksum_file=`basename $checksum_source`
	pushd $target_dir >/dev/null
	if [ -f .$checksum_file ]; then
		if diff .$checksum_file $checksum_file >/dev/null 2>&1; then
			return 0
		fi
		rm -f .$checksum_file 2>/dev/null
	fi

	if ! md5sum --quiet --check $checksum_dir/$checksum_file >/dev/null 2>&1; then
		return 1
	fi
	cp $checksum_file .$checksum_file

	popd >/dev/null
	return 0
	)
}

###################################################################################
# Install development tools   just used for compile
###################################################################################
install_dev_tools()
{
	local dev_tools="wget automake1.11 make bc libncurses5-dev libtool libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 bison flex uuid-dev build-essential iasl jq genisoimage libssl-dev"
	
	if ! (automake --version 2>/dev/null | grep 'automake (GNU automake) 1.11' >/dev/null); then
		sudo apt-get remove -y --purge automake*
	fi

	if ! (dpkg-query -l $dev_tools >/dev/null 2>&1); then
		sudo apt-get update
		if ! (sudo apt-get install -y --force-yes $dev_tools); then
			return 1
		fi
	fi
	
	return 0
}

###################################################################################
# Install toolchains
###################################################################################

install_toolchains()
{
	toolchain_content=`get_field_content ./sailing/$SAILING_CFGFILE toolchain`
	toolchain=`expr "X$toolchain_content" : 'X\([^:]*\):.*' | sed 's/ //g'`
	postfix=$(echo $toolchain | grep -Po "((\.tar)*\.(tar|bz2|gz|xz)$)" 2>/dev/null)
	toolchain_dir=${toolchain%$postfix}
	mkdir -p toolchain
	pushd toolchain >/dev/null
	
	echo "##############################################################################"
	echo "# Download & Uncompress toolchain"
	echo "##############################################################################"

	if [ ! -f ${toolchain}.sum ]; then
		rm -f .${toolchain}.sum 2>/dev/null
		wget -c $DOWNLOAD_FTP_ADDR/toolchain/${toolchain}.sum || return 1
	fi

	if [ ! -f $toolchain ] || ! check_sum . ${toolchain}.sum; then
		rm -f $toolchain 2>/dev/null
		wget -c $DOWNLOAD_FTP_ADDR/toolchain/${toolchain} || return 1
		check_sum . ${toolchain}.sum || return 1
	fi

	if [ ! -d toolchain/$toolchain_dir ]; then
		if ! sudo tar xvf $toolchain -C ./ >/dev/null 2>&1; then
			rm -rf toolchain/$toolchain_dir 2>/dev/null ; return 1
			return 1
		fi
	fi
	
	popd >/dev/null

	TOOLCHAIN_DIR=`cd toolchain/$toolchain_dir; pwd`
	export PATH=$TOOLCHAIN_DIR/bin:$PATH	

	#install toolchain
	if [ ! -d /opt/$toolchain_dir ]; then
		if ! sudo cp -r toolchain/$toolchain_dir/ /opt/; then
			return 1
		fi

		str='export PATH=$PATH:/opt/'$toolchain_dir'/bin'
		if ! grep "$str" ~/.bashrc >/dev/null; then
			echo "$str">> ~/.bashrc
		fi
	fi	

	return 0
}

###################################################################################
# Install binaries
###################################################################################
install_binaries()
{
	echo "##############################################################################"
	echo "# Download binaries"
	echo "##############################################################################"
	mkdir -p prebuild
	pushd prebuild >/dev/null
	binaries=(`get_field_content ../sailing/$SAILING_CFGFILE prebuild`)
	for binary in ${binaries[*]}; do
		target_file=`expr "X$binary" : 'X\([^:]*\):.*' | sed 's/ //g'`
		target_addr=`expr "X$binary" : 'X[^:]*:\(.*\)' | sed 's/ //g'`
		binary_file=`basename $target_addr`
		if [ ! -f ${binary_file}.sum ]; then
			rm -f .${binary_file}.sum 2>/dev/null
			wget -c $DOWNLOAD_FTP_ADDR/${target_addr}.sum || return 1
		fi

		if [ ! -f $binary_file ] || ! check_sum . ${binary_file}.sum; then
			rm -f $binary_file 2>/dev/null
			wget -c $DOWNLOAD_FTP_ADDR/$target_addr || return 1
			check_sum . ${binary_file}.sum || return 1
		fi

		if [ x"$target_file" != x"$binary_file" ]; then
			rm -f $target_file 2>/dev/null
			ln -s $binary_file $target_file
		fi
	done

	if [[ $? != 0 ]]; then
		echo -e "\033[31mError! Download binaries failed!\033[0m" ; exit 1
	fi

	download_uefi=(`sed -n "/<uefi>/,/<\/uefi>/p"  ../sailing/$SAILING_CFGFILE 2>/dev/null | sed -e '/^$/d' | sed 's/ //g'`)
	unset download_uefi[0]
	unset download_uefi[${#download_uefi[@]}]
	download_grubefi=${download_uefi[*]}
	grubefi=${download_grubefi##*/}

	if [ ! -f ${grubefi}.sum ]; then
		rm -f .${grubefi}.sum 2>/dev/null
		wget -c ${download_grubefi}.sum || return 1
	fi

	if [ ! -f $grubefi ] || ! check_sum . ${grubefi}.sum; then
		rm -f $grubefi 2>/dev/null
		wget -c $download_grubefi || return 1
		check_sum . ${grubefi}.sum || return 1
	fi

	popd >/dev/null

	mkdir -p $OUTPUT_DIR/binary/arm64/ 2>/dev/null
	cp -f prebuild/mini-rootfs.cpio.gz $OUTPUT_DIR/binary/arm64 || return 1 echo ""
	cp -f prebuild/deploy-utils.tar.bz2 $OUTPUT_DIR/binary/arm64 || return 1
	cp -f prebuild/grubaa64.efi $OUTPUT_DIR/binary/arm64 || return 1
	cp -f prebuild/grub.cfg $OUTPUT_DIR/binary/arm64 || return 1

}

###################################################################################
# Priority install distros (default distros: CentOS)
###################################################################################
prior_install_distro()
{
	distro_files=`get_field_content ./sailing/$SAILING_CFGFILE distro`
	ftp_file=`echo $distro_files | tr ' ' '\n' | grep -Po "(?<=${distro}_ARM64.tar.gz:)(.*)"`
	distro_link=CentOS_ARM64.tar.gz
	distro_file=${ftp_file##*/}
	distro=CentOS
	echo "##############################################################################"
	echo "# Install distros (default distros: CentOS)"
	echo "##############################################################################"
	mkdir -p distro
	pushd distro >/dev/null
	if [ ! -f ${distro_file}.sum ]; then
		wget -c $DOWNLOAD_FTP_ADDR/${ftp_file}.sum || return 1
	fi

	if [ ! -f $distro_file ] || ! check_sum . ${distro_file}.sum; then
		rm -f $distro_file 2>/dev/null
		wget -c $DOWNLOAD_FTP_ADDR/$ftp_file || return 1
		check_sum . ${distro_file}.sum || return 1
	fi

	if [ ! -f  $distro_link ] || [ ! -f  ${distro_link}.sum ]; then
		rm -f $distro_link ${distro_link}.sum 2>/dev/null
		ln -s $distro_file  $distro_link
		ln -s ${distro_file}.sum ${distro_link}.sum
	fi
	popd >/dev/null

	echo ""	
	echo "##############################################################################"
	echo "# Uncompress distros (distros: $DISTROS)"
	echo "##############################################################################"

	mkdir -p $OUTPUT_DIR/distro/$distro

	if ! sudo tar xvf distro/$distro_link -C $OUTPUT_DIR/distro/$distro >/dev/null 2>&1; then
		sudo rm -rf $OUTPUT_DIR/distro/$distro
		return 1
	fi
	
	cp distro/${distro}_ARM64.tar.gz.sum $OUTPUT_DIR/distro/.${distro}_ARM64.tar.gz.sum
	sudo rm -rf $OUTPUT_DIR/distro/$distro/lib/modules/*

	echo ""
}

###################################################################################
# create_distros
###################################################################################
create_distros()
{
	echo "---------------------------------------------------------------"
	echo "- Create distros (distros: $DISTROS, distro dir: $OUTPUT_DIR/distro)"
	echo "---------------------------------------------------------------"
	if [ -f $OUTPUT_DIR/distro/${DISTROS}_ARM64.tar.gz ]; then
		return 0
	fi

	if [ ! -d $OUTPUT_DIR/distro/$DISTROS ]; then
		echo "Error! $OUTPUT_DIR/distro/$DISTROS is not exist!" >&2 ; return 1
	fi

	pushd $OUTPUT_DIR/distro/$DISTROS  >/dev/null
	if ! (sudo tar czvf ../${DISTROS}_ARM64.tar.gz *); then
		echo "Error! Create ${DISTROS}_ARM64.tar.gz failed!" >&2
		return 1
	fi
	popd >/dev/null
	echo "- Create distros done!"
	echo ""
}

###################################################################################
# Create distros softlink
###################################################################################
create_distros_softlink()
{

	echo "---------------------------------------------------------------"
	echo "- Create distros softlink (distros: $DISTROS)"
	echo "---------------------------------------------------------------"

	pushd $OUTPUT_DIR/binary/arm64 >/dev/null

	rm -f ${DISTROS}_ARM64.tar.gz 2>/dev/null
	ln -s ../../distro/${DISTROS}_ARM64.tar.gz

	popd >/dev/null
	echo "- Create distros softlink done!"
	echo ""
}

###################################################################################
# Later install distros (default distros: CentOS)
###################################################################################
late_install_distro()
{
	if ! create_distros; then
		echo -e "\033[31mError! Create distro failed!\033[0m" ; exit 1
	fi

	if ! create_distros_softlink; then
		echo -e "\033[31mError! Create distro softlink failed!\033[0m" ; exit 1
	fi
}

###################################################################################
# Build kernel
###################################################################################
build_kernel()
{
	mkdir -p $OUTPUT_DIR/kernel
	kernel_dir=$(cd $OUTPUT_DIR/kernel; pwd)
	kernel_bin=$kernel_dir/arch/arm64/boot/Image
	rootfs=$(cd $OUTPUT_DIR/distro/CentOS; pwd)

	cp -f kernel/arch/arm64/configs/$ESTUARY_TE_CONFIG  $kernel_dir/.sailing.config
	pushd kernel >/dev/null

	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$kernel_dir KCONFIG_ALLCONFIG=$kernel_dir/.sailing.config alldefconfig
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$kernel_dir -j${CORE_NUM} ${kernel_bin##*/}
	#Compile kernel module
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$kernel_dir modules -j${CORE_NUM}
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$kernel_dir modules_install INSTALL_MOD_PATH=$rootfs
	#Compile firmware	
	mkdir -p  $rootfs/lib/firmware
	make PATH=$PATH ARCH=$ARCH CROSS_COMPILE=$cross_compile O=$kernel_dir -j${core_num} firmware_install INSTALL_FW_PATH=$rootfs/lib/firmware
	popd >/dev/null

	cp $kernel_bin $OUTPUT_DIR/binary/arm64/
	cp $kernel_dir/vmlinux $OUTPUT_DIR/binary/arm64/
	cp $kernel_dir/System.map $OUTPUT_DIR/binary/arm64/

}

###################################################################################
# Quick Deployment INPUT : 1) iso/usb/pxe
###################################################################################
quick_deploy()
{
	echo "/*---------------------------------------------------------------"
	echo "- deploy type: $deploy_type, target device: $deploy_device, boards mac: $BOARDS_MAC"
	echo "- platform: D05, distros: CentOS, capacity: 50GB"
	echo "- binary directory: $OUTPUT_DIR/binary/arm64"
	echo "---------------------------------------------------------------*/"
	
	bin_dir=$OUTPUT_DIR/binary/arm64
	
	if [ x"$deploy_type" = x"usb" ]; then
		sailing/deploy/mkusbinstall.sh --target=$deploy_device --platforms=$PLATFORMS --distros=$DISTROS --capacity=$CAPACITY --bindir=$bin_dir || exit 1
	elif [ x"$deploy_type" = x"iso" ]; then
	if [ ! -f $bin_dir/Estuary.iso ]; then
		sailing/deploy/mkisoimg.sh --platforms=$PLATFORMS --distros=$DISTROS --capacity=$CAPACITY --disklabel="Estuary-TE" --bindir=$bin_dir || exit 1
		mv Estuary-TE.iso $bin_dir/ || exit 1
	fi
	elif [ x"$deploy_type" = x"pxe" ]; then
		sailing/deploy/mkpxe.sh --platforms=$PLATFORMS --distros=$DISTROS --capacity=$CAPACITY --boardmac=$BOARDS_MAC --bindir=$bin_dir || exit 1
	else
		echo "Unknow deploy type!" >&2 ; exit 1
	fi	

}

###################################################################################
# Get all args
###################################################################################

while test $# != 0
do
        case $1 in
        	--*=*) ac_option=`expr "X$1" : 'X\([^=]*\)='` ; ac_optarg=`expr "X$1" : 'X[^=]*=\(.*\)'` ; ac_shift=: ;;
        	-*) ac_option=$1 ; ac_optarg=$2; ac_shift=shift ;;
        	*) ac_option=$1 ; ac_shift=: ;;
        esac

        case $ac_option in
                clean) CLEAN=yes ;;
                -h | --help) Usage ; exit 0 ;;      
                --builddir) OUTPUT_DIR=$ac_optarg ;;
                --deploy) DEPLOY=$ac_optarg 
					deploy_type=`echo "$ac_optarg" | awk -F ':' '{print $1}'`
					deploy_device=`echo "$ac_optarg" | awk -F ':' '{print $2}'`;;
                --mac) BOARDS_MAC=$ac_optarg ;;
                -a) if [ x"$ac_optarg" = x"China" ]; then DOWNLOAD_FTP_ADDR=$CHINA_INTERAL_FTP_ADDR; fi ;;
                *) Usage ; echo "Unknown option $1" ; exit 1 ;;
        esac
	
        $ac_shift
        shift
done
###################################################################################
# Install Sailing Project  Environment
###################################################################################
if ! install_dev_tools; then
	echo -e "\033[31mError! Install development tools failed!\033[0m" ; exit 1
fi

if ! install_toolchains; then
	echo -e "\033[31mError! Install cross-compile toolchains failed!\033[0m" ; exit 1
fi

if ! install_binaries; then
	echo -e "\033[31mError! Install binaries failed!\033[0m" ; exit 1
fi

if ! prior_install_distro; then
	echo -e "\033[31mError! Install distro failed!\033[0m" ; exit 1
fi
###################################################################################
# Build Kernel Environment
###################################################################################
if ! build_kernel; then
	echo -e "\033[31mError! Build kernel failed!\033[0m" ; exit 1
fi

if ! late_install_distro; then
	echo -e "\033[31mError! Late install distro failed!\033[0m" ; exit 1
fi
###################################################################################
# Quick Deploy
###################################################################################
if ! quick_deploy ; then
	echo -e "\033[31mError! Quick deploy failed!\033[0m" ; exit 1
fi

