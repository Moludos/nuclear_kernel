#!/system/bin/sh

# *****************************
# Bacon Cyanogenmod 12 version
#
# V0.1
# *****************************

# define basic kernel configuration
	# path to internal sd memory
	SD_PATH="/data/media/0"

	# block devices
	SYSTEM_DEVICE="/dev/block/platform/msm_sdcc.1/by-name/system"
	CACHE_DEVICE="/dev/block/platform/msm_sdcc.1/by-name/cache"
	DATA_DEVICE="/dev/block/platform/msm_sdcc.1/by-name/userdata"

# define file paths
	NUCLEAR_DATA_PATH="$SD_PATH/nuclear-kernel-data"
	NUCLEAR_LOGFILE="$NUCLEAR_DATA_PATH/nuclear-kernel.log"
	NUCLEAR_STARTCONFIG="/data/.nuclear/startconfig"
	NUCLEAR_STARTCONFIG_EARLY="/data/.nuclear/startconfig_early"
	NUCLEAR_STARTCONFIG_DONE="/data/.nuclear/startconfig_done"
	CWM_RESET_ZIP="nuclear-config-reset-v4.zip"
	INITD_ENABLER="/data/.nuclear/enable-initd"
	BUSYBOX_ENABLER="/data/.nuclear/enable-busybox"
	FRANDOM_ENABLER="/data/.nuclear/enable-frandom"
	PERMISSIVE_ENABLER="/data/.nuclear/enable-permissive"

# If not yet existing, create a nuclear-kernel-data folder on sdcard 
# which is used for many purposes,
# always set permissions and owners correctly for pathes and files
	if [ ! -d "$NUCLEAR_DATA_PATH" ] ; then
		/sbin/busybox mkdir $NUCLEAR_DATA_PATH
	fi

	/sbin/busybox chmod 775 $SD_PATH
	/sbin/busybox chown 1023:1023 $SD_PATH

	/sbin/busybox chmod -R 775 $NUCLEAR_DATA_PATH
	/sbin/busybox chown -R 1023:1023 $NUCLEAR_DATA_PATH

# maintain log file history
	rm $NUCLEAR_LOGFILE.3
	mv $NUCLEAR_LOGFILE.2 $NUCLEAR_LOGFILE.3
	mv $NUCLEAR_LOGFILE.1 $NUCLEAR_LOGFILE.2
	mv $NUCLEAR_LOGFILE $NUCLEAR_LOGFILE.1

# Initialize the log file (chmod to make it readable also via /sdcard link)
	echo $(date) Nuclear-Kernel initialisation started > $NUCLEAR_LOGFILE
	/sbin/busybox chmod 666 $NUCLEAR_LOGFILE
	/sbin/busybox cat /proc/version >> $NUCLEAR_LOGFILE
	echo "=========================" >> $NUCLEAR_LOGFILE
	/sbin/busybox grep ro.build.version /system/build.prop >> $NUCLEAR_LOGFILE
	echo "=========================" >> $NUCLEAR_LOGFILE

# Correct /sbin and /res directory and file permissions
	mount -o remount,rw rootfs /

	# change permissions of /sbin folder and scripts in /res/bc
	/sbin/busybox chmod -R 755 /sbin
	/sbin/busybox chmod 755 /res/bc/*

	/sbin/busybox sync
	mount -o remount,ro rootfs /

# remove any obsolete Nuclear-Config V2 startconfig done file
	/sbin/busybox rm -f $NUCLEAR_STARTCONFIG_DONE

# remove not used configuration files for frandom and busybox
	/sbin/busybox rm -f $BUSYBOX_ENABLER
	/sbin/busybox rm -f $FRANDOM_ENABLER
	
# Apply Nuclear-Kernel default settings

	# Sdcard buffer tweaks default to 1024 kb
	echo 1024 > /sys/block/mmcblk0/bdi/read_ahead_kb
	/sbin/busybox sync

	# Ext4 tweaks default to on
	/sbin/busybox sync
	mount -o remount,commit=20,noatime $CACHE_DEVICE /cache
	/sbin/busybox sync
	mount -o remount,commit=20,noatime $DATA_DEVICE /data
	/sbin/busybox sync

	# dynamic fsync to on
	echo 1 > /sys/kernel/dyn_fsync/Dyn_fsync_active
	/sbin/busybox sync

	echo $(date) Nuclear-Kernel default settings applied >> $NUCLEAR_LOGFILE

# Execute early startconfig placed by Nuclear-Config V2 app, if there is one
	if [ -f $NUCLEAR_STARTCONFIG_EARLY ]; then
		echo $(date) "Early startup configuration found"  >> $NUCLEAR_LOGFILE
		. $NUCLEAR_STARTCONFIG_EARLY
		echo $(date) Early startup configuration applied  >> $NUCLEAR_LOGFILE
	else
		echo $(date) "No early startup configuration found"  >> $NUCLEAR_LOGFILE
	fi

# init.d support (enabler only to be considered for CM based roms)
# (zipalign scripts will not be executed as only exception)
	if [ -f $INITD_ENABLER ] ; then
		echo $(date) Execute init.d scripts start >> $NUCLEAR_LOGFILE
		if cd /system/etc/init.d >/dev/null 2>&1 ; then
			for file in * ; do
				if ! cat "$file" >/dev/null 2>&1 ; then continue ; fi
				if [[ "$file" == *zipalign* ]]; then continue ; fi
				echo $(date) init.d file $file started >> $NUCLEAR_LOGFILE
				/system/bin/sh "$file"
				echo $(date) init.d file $file executed >> $NUCLEAR_LOGFILE
			done
		fi
		echo $(date) Finished executing init.d scripts >> $NUCLEAR_LOGFILE
	else
		echo $(date) init.d script handling by kernel disabled >> $NUCLEAR_LOGFILE
	fi

# Now wait for the rom to finish booting up
# (by checking for the android acore process)
	echo $(date) Checking for Rom boot trigger... >> $NUCLEAR_LOGFILE
	while ! /sbin/busybox pgrep com.android.systemui ; do
	  /sbin/busybox sleep 1
	done
	echo $(date) Rom boot trigger detected, waiting a few more seconds... >> $NUCLEAR_LOGFILE
	/sbin/busybox sleep 20

# Interaction with Nuclear-Config app V2
	# save original stock values for selected parameters
	cat /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table > /dev/bk_orig_cpu_voltage
	cat /sys/kernel/charge_levels/charge_level_ac > /dev/bk_orig_charge_level_ac
	cat /sys/kernel/charge_levels/charge_level_usb > /dev/bk_orig_charge_level_usb
	cat /sys/module/lowmemorykiller/parameters/minfree > /dev/bk_orig_minfree
	/sbin/busybox lsmod > /dev/bk_orig_modules
	cat /sys/class/kgsl/kgsl-3d0/devfreq/governor > /dev/bk_orig_gpu_governor
	cat /sys/class/kgsl/kgsl-3d0/min_pwrlevel > /dev/bk_orig_min_pwrlevel
	cat /sys/class/kgsl/kgsl-3d0/max_pwrlevel > /dev/bk_orig_max_pwrlevel

	# if there is a startconfig placed by Nuclear-Config V2 app, execute it;
	if [ -f $NUCLEAR_STARTCONFIG ]; then
		echo $(date) "Startup configuration found"  >> $NUCLEAR_LOGFILE
		. $NUCLEAR_STARTCONFIG
		echo $(date) Startup configuration applied  >> $NUCLEAR_LOGFILE
	else
		echo $(date) "No startup configuration found"  >> $NUCLEAR_LOGFILE
	fi

# Turn off debugging for certain modules
	echo 0 > /sys/module/kernel/parameters/initcall_debug
	echo 0 > /sys/module/lowmemorykiller/parameters/debug_level
	echo 0 > /sys/module/alarm/parameters/debug_mask
	echo 0 > /sys/module/alarm_dev/parameters/debug_mask
	echo 0 > /sys/module/binder/parameters/debug_mask
	echo 0 > /sys/module/xt_qtaguid/parameters/debug_mask

# Auto root support
	if [ -f $SD_PATH/autoroot ]; then

		echo $(date) Auto root is enabled >> $NUCLEAR_LOGFILE

		mount -o remount,rw -t ext4 $SYSTEM_DEVICE /system

		/sbin/busybox mkdir /system/bin/.ext
		/sbin/busybox cp /res/misc/su /system/xbin/su
		/sbin/busybox cp /res/misc/su /system/xbin/daemonsu
		/sbin/busybox cp /res/misc/su /system/bin/.ext/.su
		/sbin/busybox cp /res/misc/install-recovery.sh /system/etc/install-recovery.sh
		/sbin/busybox echo /system/etc/.installed_su_daemon
		
		/sbin/busybox chown 0.0 /system/bin/.ext
		/sbin/busybox chmod 0777 /system/bin/.ext
		/sbin/busybox chown 0.0 /system/xbin/su
		/sbin/busybox chmod 6755 /system/xbin/su
		/sbin/busybox chown 0.0 /system/xbin/daemonsu
		/sbin/busybox chmod 6755 /system/xbin/daemonsu
		/sbin/busybox chown 0.0 /system/bin/.ext/.su
		/sbin/busybox chmod 6755 /system/bin/.ext/.su
		/sbin/busybox chown 0.0 /system/etc/install-recovery.sh
		/sbin/busybox chmod 0755 /system/etc/install-recovery.sh
		/sbin/busybox chown 0.0 /system/etc/.installed_su_daemon
		/sbin/busybox chmod 0644 /system/etc/.installed_su_daemon

		/system/bin/sh /system/etc/install-recovery.sh

		/sbin/busybox sync
		
		mount -o remount,ro -t ext4 $SYSTEM_DEVICE /system
		echo $(date) Auto root: su installed >> $NUCLEAR_LOGFILE

		rm $SD_PATH/autoroot
	fi

# EFS backup
	EFS_BACKUP_INT="$NUCLEAR_DATA_PATH/efs.tar.gz"

	if [ ! -f $EFS_BACKUP_INT ]; then

		dd if=/dev/block/mmcblk0p10 of=$NUCLEAR_DATA_PATH/modemst1.bin bs=512
		dd if=/dev/block/mmcblk0p11 of=$NUCLEAR_DATA_PATH/modemst2.bin bs=512

		cd $NUCLEAR_DATA_PATH
		/sbin/busybox tar cvz -f $EFS_BACKUP_INT modemst*
		/sbin/busybox chmod 666 $EFS_BACKUP_INT

		rm $NUCLEAR_DATA_PATH/modemst*
		
		echo $(date) EFS Backup: Not found, now created one >> $NUCLEAR_LOGFILE
	fi

# Copy reset recovery zip in nuclear-kernel-data folder, delete older versions first
	CWM_RESET_ZIP_SOURCE="/res/misc/$CWM_RESET_ZIP"
	CWM_RESET_ZIP_TARGET="$NUCLEAR_DATA_PATH/$CWM_RESET_ZIP"

	if [ ! -f $CWM_RESET_ZIP_TARGET ]; then

		/sbin/busybox rm $NUCLEAR_DATA_PATH/nuclear-config-reset*
		/sbin/busybox cp $CWM_RESET_ZIP_SOURCE $CWM_RESET_ZIP_TARGET
		/sbin/busybox chmod 666 $CWM_RESET_ZIP_TARGET

		echo $(date) Recovery reset zip copied >> $NUCLEAR_LOGFILE
	fi

# If not explicitely configured to permissive, set SELinux to enforcing and restart mpdecision
	if [ ! -f $PERMISSIVE_ENABLER ]; then
		echo "1" > /sys/fs/selinux/enforce

		stop mpdecision
		/sbin/busybox sleep 0.5
		start mpdecision

		echo $(date) "SELinux: enforcing" >> $NUCLEAR_LOGFILE
	else
		echo $(date) "SELinux: permissive" >> $NUCLEAR_LOGFILE
	fi

# Finished
	echo $(date) Nuclear-Kernel initialisation completed >> $NUCLEAR_LOGFILE
	echo $(date) "Loaded early startconfig was:" >> $NUCLEAR_LOGFILE
	cat $NUCLEAR_STARTCONFIG_EARLY >> $NUCLEAR_LOGFILE
	echo $(date) "Loaded startconfig was:" >> $NUCLEAR_LOGFILE
	cat $NUCLEAR_STARTCONFIG >> $NUCLEAR_LOGFILE
	echo $(date) End of kernel startup logfile >> $NUCLEAR_LOGFILE
