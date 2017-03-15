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
CAPACITY=50
DISTROS=CentOS
RELEASE_ISO=Sailing
CROSS_COMPILE=aarch64-linux-gnu-
ESTUARY_TE_CONFIG=estuary_te_defconfig
CHECKSUM_FILE=checksum.sum
CORE_NUM=`cat /proc/cpuinfo | grep "processor" | wc -l`
DOWNLOAD_ESTUARY=https://github.com/open-estuary/estuary.git
COMMIT_SERIAl=300efe84165fa8651c6d694fc69debfc8aade6b7
DOWNLOAD_FTP_ADDR=http://open-estuary.org/download/AllDownloads/FolderNotVisibleOnWebsite/EstuaryInternalConfig
CHINA_INTERAL_FTP_ADDR=ftp://117.78.41.188/FolderNotVisibleOnWebsite/EstuaryInternalConfig
START_SERVICE_PATH=etc/systemd/system/multi-user.target.wants
START_BASIS_SERVICE_PATH=etc/systemd/system/basic.target.wants
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



###################################################################################
# Usage
###################################################################################
Usage()
{
cat << EOF
Usage: ./sailing/build.sh [options]
Options:
	-h, --help: Display this information
	-a: download address, China or Estuary(default Estuary)	
	clean: Clean all binary files

	--builddir: Build output directory, default is workspace

Example:
	./sailing/build.sh --help
	./estuary/build.sh clean --builddir=./workspace
	./sailing/build.sh --builddir=./workspace --deploy=iso -a Estuary
	./sailing/build.sh --builddir=./workspace --deploy=iso -a China
	./sailing/build.sh --builddir=./workspace --deploy=usb:/dev/sdb --deploy=iso
	./sailing/build.sh --builddir=./workspace --distro=Ubuntu,CentOS  --capacity=50,50 --deploy=usb:/dev/sdb --deploy=iso
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

	TOOLCHAIN_PATH=`cd toolchain/$toolchain_dir; pwd`
	export PATH=$TOOLCHAIN_PATH/bin:$PATH

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
		binary_file=${binary##*/}
		if [ ! -f ${binary_file}.sum ]; then
			rm -f .${binary_file}.sum 2>/dev/null
			wget -c ${binary}.sum || return 1
		fi

		if [ ! -f $binary_file ] || ! check_sum . ${binary_file}.sum; then
			rm -f $binary_file 2>/dev/null
			wget -c $binary || return 1
			check_sum . ${binary_file}.sum || return 1
		fi
	done

	if [[ $? != 0 ]]; then
		echo -e "\033[31mError! Download binaries failed!\033[0m" ; exit 1
	fi

	popd >/dev/null

	mkdir -p $OUTPUT_DIR/binary/arm64/ 2>/dev/null
	cp -f prebuild/mini-rootfs.cpio.gz $OUTPUT_DIR/binary/arm64 || return 1 echo ""
	cp -f prebuild/deploy-utils.tar.bz2 $OUTPUT_DIR/binary/arm64 || return 1
	cp -f prebuild/grubaa64.efi $OUTPUT_DIR/binary/arm64 || return 1
	cp -f prebuild/grub.cfg $OUTPUT_DIR/binary/arm64 || return 1

}
###################################################################################
# Install docs/grub
###################################################################################
install_docs()
{
	mkdir -p $OUTPUT_DIR/binary/doc
	echo "##############################################################################"
	echo "# Download docs & uefi"
	echo "##############################################################################"

	docs=(`get_field_content sailing/$SAILING_CFGFILE doc`)
	pushd $OUTPUT_DIR/binary/doc >/dev/null
	for doc in ${docs[*]}; do
		if [ ! -f checksum.sum ] ; then
			ftp_sailing=${doc%/*}
			rm -f checksum.sum 2>/dev/null
			wget -c $ftp_sailing/checksum.sum || return 1
		fi
		doc_file=${doc##*/}
		if [ ! -f $doc_file ] ; then
			rm -f $doc_file 2>/dev/null
			wget -c "$doc" || return 1
		fi
	done
	if  grep Sailing $CHECKSUM_FILE >/dev/null 2>&1;then
			sed -i /Sailing/d  $CHECKSUM_FILE
	fi

	if ! check_sum . $CHECKSUM_FILE; then
		echo "Error! Checksum docs & uefi failed!" >&2 ; return 1
	fi
	uefi=`grep bios $CHECKSUM_FILE | awk '{print $2}'`
	cp -a $uefi ../arm64/
	popd >/dev/null
}
###################################################################################
# Priority install distros (default distros: CentOS)
###################################################################################
prior_install_distro()
{

	distros=($(echo $DISTROS | tr ',' ' '))
	distro_files=(`get_field_content ./sailing/$SAILING_CFGFILE distro`)
	echo "##############################################################################"
	echo "# Install distros (default distros: CentOS)"
	echo "##############################################################################"
	mkdir -p distro
	pushd distro >/dev/null
	for distro in ${distros[@]}; do
		distro_file=`echo ${distro_files[*]} | tr ' ' '\n' | grep -Po "${distro}_ARM64.tar.gz"`
		ftp_distro_file=`echo ${distro_files[*]} | tr ' ' '\n' | grep "${distro}_ARM64.tar.gz"`
		if [ ! -f ${distro_file}.sum ]; then
			wget -c ${ftp_distro_file}.sum || return 1
		fi
		if [ ! -f $distro_file ] || ! check_sum . ${distro_file}.sum; then
			rm -f $distro_file 2>/dev/null
			wget -c $ftp_distro_file || return 1
			check_sum . ${distro_file}.sum || return 1
		fi
	done
	popd >/dev/null

	echo ""	
	echo "##############################################################################"
	echo "# Uncompress distros (distros: $DISTROS)"
	echo "##############################################################################"
	version=`cd kernel && git describe --tags $(git rev-list --tags --max-count=1)`
	for distro in ${distros[@]}; do

		if [ ! -f $OUTPUT_DIR/distro/.${distro}_ARM64.tar.gz.sum ] || [ ! -d $OUTPUT_DIR/distro/$distro ] || \
			! (diff distro/${distro}_ARM64.tar.gz.sum $OUTPUT_DIR/distro/.${distro}_ARM64.tar.gz.sum >/dev/null 2>&1); then
			sudo rm -rf $OUTPUT_DIR/distro/$distro
			rm -f $OUTPUT_DIR/distro/.${distro}_ARM64.tar.gz.sum 2>/dev/null
			rm -rf $OUTPUT_DIR/distro/${distro}_ARM64.* 2>/dev/null

			mkdir -p $OUTPUT_DIR/distro/$distro
			if ! sudo tar xvf distro/${distro}_ARM64.tar.gz -C $OUTPUT_DIR/distro/$distro >/dev/null 2>&1; then
				sudo rm -rf $OUTPUT_DIR/distro/$distro
				return 1
			else
				cp distro/${distro}_ARM64.tar.gz.sum $OUTPUT_DIR/distro/.${distro}_ARM64.tar.gz.sum
				touch -a $OUTPUT_DIR/distro/$distro/etc/version
				echo $version > $OUTPUT_DIR/distro/$distro/etc/version
				sudo rm -rf $OUTPUT_DIR/distro/$distro/lib/modules/*
			fi
		fi
	done
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

	distros=($(echo $DISTROS | tr ',' ' '))
	distro_dir=$OUTPUT_DIR/distro
	for distro in ${distros[*]}; do
		if [ -f $distro_dir/${distro}_ARM64.tar.gz ]; then
			continue
		fi

		#below especially deal with CentOS
		if [ -h $distro_dir/$distro/$START_SERVICE_PATH/auditd.service ]; then
			rm -f $distro_dir/$distro/$START_SERVICE_PATH/auditd.service
		fi

		if [ -h $distro_dir/$distro/$START_SERVICE_PATH/irqbalance.service ]; then
			rm -f $distro_dir/$distro/$START_SERVICE_PATH/irqbalance.service
		fi

		if [ -h $distro_dir/$distro/$START_BASIS_SERVICE_PATH/firewalld.service ]; then
			rm -f $distro_dir/$distro/$START_BASIS_SERVICE_PATH/firewalld.service
		fi

		if [ ! -d $distro_dir/$distro ]; then
			echo "Error! $distro_dir/$distro is not exist!" >&2 ; return 1
		fi

		pushd $distro_dir/$distro
		if ! (sudo tar czvf ../${distro}_ARM64.tar.gz *); then
			echo "Error! Create ${distro}_ARM64.tar.gz failed!" >&2
			return 1
		fi
		popd >/dev/null
	done
	echo "- Create distros done!"
	echo ""
}
###################################################################################
# Create distros softlink
###################################################################################
create_distros_softlink()
{
	distros=($(echo $DISTROS | tr ',' ' '))
	echo "---------------------------------------------------------------"
	echo "- Create distros softlink (distros: $DISTROS)"
	echo "---------------------------------------------------------------"

	pushd $OUTPUT_DIR/binary/arm64 >/dev/null
	for distro in ${distros[*]}; do
		rm -f ${distro}_ARM64.tar.gz 2>/dev/null
		ln -s ../../distro/${distro}_ARM64.tar.gz
	done
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
	distros=($(echo $DISTROS | tr ',' ' '))
	mkdir -p $OUTPUT_DIR/kernel
	kernel_dir=$(cd $OUTPUT_DIR/kernel; pwd)
	kernel_bin=$kernel_dir/arch/arm64/boot/Image

	cp -f kernel/arch/arm64/configs/$ESTUARY_TE_CONFIG  $kernel_dir/.sailing.config
	pushd kernel >/dev/null
	for distro in ${distros[*]}; do
		rootfs=$(cd ../$OUTPUT_DIR/distro/$distro; pwd)

		make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$kernel_dir KCONFIG_ALLCONFIG=$kernel_dir/.sailing.config alldefconfig
		make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$kernel_dir -j${CORE_NUM} ${kernel_bin##*/}
		#Compile kernel module
		make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$kernel_dir modules -j${CORE_NUM}
		make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$kernel_dir modules_install INSTALL_MOD_PATH=$rootfs
		#Compile firmware
		mkdir -p  $rootfs/lib/firmware
		make PATH=$PATH ARCH=$ARCH CROSS_COMPILE=$cross_compile O=$kernel_dir -j${core_num} firmware_install INSTALL_FW_PATH=$rootfs/lib/firmware
	done
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
	echo "- deploy type: $DEPLOY_TYPE, target device: $DEPLOY_DEVICE, boards mac: $BOARDS_MAC"
	echo "- platform: D05, distros: CentOS, capacity: 50GB"
	echo "- binary directory: $OUTPUT_DIR/binary/arm64"
	echo "---------------------------------------------------------------*/"
	
	bin_dir=$OUTPUT_DIR/binary/arm64
	
	if [ x"$DEPLOY_TYPE" = x"usb" ]; then
		$estuary_script_path/mkusbinstall.sh --target=$DEPLOY_DEVICE --platforms=$PLATFORMS --distros=$DISTROS --capacity=$CAPACITY --bindir=$bin_dir || exit 1
	elif [ x"$DEPLOY_TYPE" = x"iso" ]; then
	if [ ! -f $bin_dir/Estuary.iso ]; then
		$estuary_script_path/mkisoimg.sh --platforms=$PLATFORMS --distros=$DISTROS --capacity=$CAPACITY --disklabel=$RELEASE_ISO --bindir=$bin_dir || exit 1
	fi
	elif [ x"$DEPLOY_TYPE" = x"pxe" ]; then
		$estuary_script_path/mkpxe.sh --platforms=$PLATFORMS --distros=$DISTROS --capacity=$CAPACITY --boardmac=$BOARDS_MAC --bindir=$bin_dir || exit 1
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
		-d | --distro) DISTROS=$ac_optarg ;;
                --builddir) OUTPUT_DIR=$ac_optarg ;;
                --deploy)
			DEPLOY_TYPE=`echo "$ac_optarg" | awk -F ':' '{print $1}'`
			DEPLOY_DEVICE=`echo "$ac_optarg" | awk -F ':' '{print $2}'`;;
		--capacity) CAPACITY=$ac_optarg ;;
		--mac) BOARDS_MAC=$ac_optarg ;;
                -a) if [ x"$ac_optarg" = x"China" ]; then DOWNLOAD_FTP_ADDR=$CHINA_INTERAL_FTP_ADDR; fi ;;
                *) Usage ; echo "Unknown option $1" ; exit 1 ;;
        esac
	
        $ac_shift
        shift
done


###################################################################################
# Default values
###################################################################################

OUTPUT_DIR=${OUTPUT_DIR:-build}
DEPLOY_TYPE=${DEPLOY_DEVICE:-iso}
DEPLOY_DEVICE=${DEPLOY_DEVICE:-/dev/sdb}
CAPACITY=${CAPACITY:-50}
###################################################################################
# fork estuary script for multiplex
###################################################################################
clone_estuary()
{
	if [ ! -d estuary ]; then
		rm -rf estuary 2>/dev/null
		git clone $DOWNLOAD_ESTUARY || return 1
	fi

	estuary_script_path=$(cd estuary/deploy; pwd)

	pushd $estuary_script_path >/dev/null
	git checkout $COMMIT_SERIAl
	cp -f ../../patches/*  ./

	if ! git apply --check *.patch; then
		echo -e "\033[31mError! Git apply-check patch failed!\033[0m" ; exit 1
	fi

	if ! git am  *.patch; then
		echo -e "\033[31mError! Git am patch failed!\033[0m" ; exit 1
	fi
	rm *.patch
	popd >/dev/null
}

###################################################################################
# Clean project
###################################################################################
clean_sailing()
{
	if [ x"$CLEAN" = x"yes" ]; then
		echo "##############################################################################"
		echo "# Clean project builddir: $OUTPUT_DIR"
		echo "##############################################################################"

		sudo rm -rf $OUTPUT_DIR/kernel
		rm -f $OUTPUT_DIR/binary/arm64/Image $OUTPUT_DIR/binary/arm64/vmlinux $OUTPUT_DIR/binary/arm64/System.map
		rm -f $OUTPUT_DIR/binary/arm64/${RELEASE_ISO}.iso 2>/dev/null
		echo "Clean binary files done!"
		exit 0
	fi
}

if ! clean_sailing; then
	echo -e "\033[31mError! Clean Sailing failed!\033[0m" ; exit 1
fi
###################################################################################
# Install Sailing Project  Environment
###################################################################################

if ! clone_estuary; then
	echo -e "\033[31mError! Fork estuary multiplex script failed!\033[0m" ; exit 1
fi

if ! install_dev_tools; then
	echo -e "\033[31mError! Install development tools failed!\033[0m" ; exit 1
fi

if ! install_toolchains; then
	echo -e "\033[31mError! Install cross-compile toolchains failed!\033[0m" ; exit 1
fi

if ! install_binaries; then
	echo -e "\033[31mError! Install binaries failed!\033[0m" ; exit 1
fi

if ! install_docs; then
	echo -e "\033[31mError! Download docs & uefi failed!\033[0m" ; exit 1
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

