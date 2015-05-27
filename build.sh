#!/bin/bash

# Bash Color
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

clear

# Resources
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="zImage"
DTBIMAGE="dtb"
DEFCONFIG="nuclear_defconfig"

# Kernel Details
BASE_DN_VER="NuclearKernel"
VER="_V.6_CM12.1"
DN_VER="$BASE_DN_VER$VER"

# Vars
export LOCALVERSION=~`echo $DN_VER`
export CROSS_COMPILE=${HOME}/Android/toolchains/uber6/bin/arm-eabi-
export ARCH=arm
export SUBARCH=arm
export KBUILD_BUILD_USER=moludo
export KBUILD_BUILD_HOST=nuclearteam

# Paths
KERNEL_DIR=`pwd`
REPACK_DIR="${HOME}/kerneldark/anykernel"
PATCH_DIR="${HOME}/kerneldark/anykernel/patch"
# MODULES_DIR="${HOME}/kerneldark/anykernel/modules"
ZIP_MOVE="${HOME}/kerneldark/final"
ZIMAGE_DIR="${HOME}/kerneldark/arch/arm/boot"

# Functions
function clean_all {
#		rm -rf $MODULES_DIR/*
		cd $REPACK_DIR
		rm -rf $KERNEL
		rm -rf $DTBIMAGE
		git reset --hard > /dev/null 2>&1
		git clean -f -d > /dev/null 2>&1
		cd $KERNEL_DIR
		echo
		make clean && make mrproper
}

function make_kernel {
		echo
		make $DEFCONFIG
		make $THREAD
		cp -vr $ZIMAGE_DIR/$KERNEL $REPACK_DIR
}

# function make_modules {
#		rm `echo $MODULES_DIR"/*"`
#		find $KERNEL_DIR -name '*.ko' -exec cp -v {} $MODULES_DIR \;
# }

function make_dtb {
		$REPACK_DIR/tools/dtbToolCM -2 -o $REPACK_DIR/$DTBIMAGE -s 2048 -p scripts/dtc/ arch/arm/boot/
}

function make_zip {
		cd $REPACK_DIR
		zip -r9 `echo $DN_VER`.zip *
		mv  `echo $DN_VER`.zip $ZIP_MOVE
		cd $KERNEL_DIR
}


DATE_START=$(date +"%s")

echo -e "${green}"

echo "-------------------"
echo "Version del kernel:"
echo "-------------------"

echo -e "${red}"; echo -e "${blink_red}"; echo "$DN_VER"; echo -e "${restore}";

echo -e "${green}"
echo "--------------------------"
echo "Compilando Nuclear Kernel:"
echo "--------------------------"
echo -e "${restore}"

while read -p "¿Quieres eliminar compilaciones antiguas (y/n)? " cchoice
do
case "$cchoice" in
	y|Y )
		clean_all
		echo
		echo "Compilaciones antiguas eliminadas"
		break
		;;
	n|N )
		break
		;;
	* )
		echo
		echo "Inválido intentarlo de nuevo!"
		echo
		;;
esac
done

echo

while read -p "Quieres compilar el kernel (y/n)? " dchoice
do
case "$dchoice" in
	y|Y)
		make_kernel
		make_dtb
#		make_modules
		make_zip
		break
		;;
	n|N )
		break
		;;
	* )
		echo
		echo "Inválido intentarlo de nuevo!"
		echo
		;;
esac
done

echo -e "${green}"
echo "--------------------------"
echo "Compilacion completada en:"
echo "--------------------------"
echo -e "${restore}"

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Tiempo: $(($DIFF / 60)) minuto(s) y $(($DIFF % 60)) segundos."
echo

