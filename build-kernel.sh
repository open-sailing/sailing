#!/bin/bash

###################################################################################
# Default values
###################################################################################
OUTPUT_DIR=${OUTPUT_DIR:-build}
CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}

###################################################################################
# build_kernel_usage
###################################################################################
build_kernel_usage()
{
cat << EOF
Usage: ./sailling/build-kernel.sh [clean] --cross=xxx --output=xxx
    clean: clean the kernel binary files (include dtb)
    --cross: cross compile prefix (if the host is not arm architecture, it must be specified.)
    --output: target binary output directory

Example:
    ./sailing/build-kernel.sh --output=workspace
    ./sailing/build-kernel.sh --output=workspace --cross=aarch64-linux-gnu-
    ./sailing/build-kernel.sh clean
EOF
}

###################################################################################
# build_kernel <output_dir>
###################################################################################

build_kernel()
{

	export ARCH=arm64
	mkdir -p ${OUTPUT_DIR}/kernel
	mkdir -p ${OUTPUT_DIR}/modules
	kernel_dir=$(cd ${OUTPUT_DIR}/kernel; pwd)
	kernel_bin=$kernel_dir/arch/arm64/boot/Image
	modules_dir=$(cd ${OUTPUT_DIR}/modules; pwd)

	core_num=`cat /proc/cpuinfo | grep "processor" | wc -l`

	sudo cp -f ./kernel/arch/arm64/configs/estuary_te_defconfig  $kernel_dir/.sailing.config
	pushd kernel >/dev/null
	sudo make O=$kernel_dir CROSS_COMPILE=${CROSS_COMPILE} KCONFIG_ALLCONFIG=$kernel_dir/.sailing.config alldefconfig
	#make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$kernel_dir menuconfig
	sudo make O=$kernel_dir CROSS_COMPILE=${CROSS_COMPILE} -j${core_num} ${kernel_bin##*/}
	#Compile kernel module
	sudo make O=$kernel_dir CROSS_COMPILE=${CROSS_COMPILE} modules -j${core_num}
	sudo make O=$kernel_dir CROSS_COMPILE=${CROSS_COMPILE} modules_install INSTALL_MOD_PATH=$modules_dir 
	#Compile firmware
	mkdir -p $modules_fir/lib/firmware
	sudo make O=$kernel_dir CROSS_COMPILE=${CROSS_COMPILE} firmware_install INSTALL_FW_PATH=$modules_dir/lib/firmware
	popd >/dev/null
	
	mkdir -p $OUTPUT_DIR/binary/arm64/ 2>/dev/null
	cp $kernel_bin $OUTPUT_DIR/binary/arm64/
	cp $kernel_dir/vmlinux $OUTPUT_DIR/binary/arm64/
	cp $kernel_dir/System.map $OUTPUT_DIR/binary/arm64/

	if [ x"$DISTROS" != x"" ]; then
		distro_module 
	fi
}

###################################################################################
# Distro replace modules
###################################################################################
distro_module()
{
	distros=($(echo $DISTROS | tr ',' ' '))
	for distro in ${distros[*]}; do
		rootfs=$(cd $OUTPUT_DIR/distro/$distro; pwd)
	
		sudo cp -af $modules_dir/lib/modules  $rootfs/lib
		sudo cp -af $modules_dir/lib/firmware $rootfs/lib
	done
}

###################################################################################
# get args
###################################################################################
while test $# != 0
do
    case $1 in
        --*=*) ac_option=`expr "X$1" : 'X\([^=]*\)='` ; ac_optarg=`expr "X$1" : 'X[^=]*=\(.*\)'` ;;
        *) ac_option=$1 ac_optarg=$2;;
    esac

    case $ac_option in
		clean) CLEAN="yes" ;;
		--cross) CROSS_COMPILE=$ac_optarg ;;
        --output) OUTPUT_DIR=$ac_optarg ;;
		-d | --distro) DISTROS=$ac_optarg ;;
        *) build_kernel_usage ; exit 1 ;;
    esac

    shift
done

###################################################################################
# clean_kernel <output_dir>
###################################################################################
clean_kernel()
{
	if [ x"$CLEAN" = x"yes" ]; then
			echo "Clean kernel ......"
			sudo rm -rf $OUTPUT_DIR/kernel  $OUTPUT_DIR/modules
			rm -f $OUTPUT_DIR/binary/arm64/Image $OUTPUT_DIR/binary/arm64/vmlinux $OUTPUT_DIR/binary/arm64/System.map
			echo "Clean binary files done!"
			exit 0
	fi
}

# build kernel or clean_kernel
if ! clean_kernel; then
        echo -e "\033[31mError! Clean kernel failed!\033[0m" ; exit 1
fi

if ! build_kernel; then
        echo -e "\033[31mError! Build kernel failed!\033[0m" ; exit 1
fi
