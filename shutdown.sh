#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  Call this file from the Administration-->Commands tab in the DD-WRT GUI
#
##########################################################################

d_baseDir=`dirname $0`

source "${d_baseDir}/includes/versions.sh"
source "${d_baseDir}/includes/defaults.sh"
if [ -f "$d_baseDir/includes/util$_version.sh" ] ; then
	source "$d_baseDir/includes/util$_version.sh"
else
	source "$d_baseDir/includes/util.sh"
fi
_configFile="$d_baseDir/config.file"
source "$_configFile"
loadconfig
source "$d_baseDir/strings/$_lang/strings.sh"

# stop the script by removing the locking directory

_oldLockDir="/tmp/YAMon3-running"

ir=$(ps | grep -v "grep" | grep -c "yamon$_file_version")
if [ ! -d $_lockDir ] && [ "$ir" -eq "0" ]; then
	echo "$_s_notrunning"
	exit 0
fi

[ -d "$_oldLockDir" ] && rmdir $_oldLockDir
[ -d $_lockDir ] && rmdir $_lockDir
if [ "$ir" -eq "0" ]; then
	echo "$_s_stopped"
	exit 0
fi

if [ "$ir" -gt "0" ]; then
	echo "$_s_stopping"
	n=0
	while [ true ] ; do
		n=$(($n + 1))
		ir=$(ps | grep -v "grep" | grep -c "yamon$_file_version")
		[ "$n" -gt "$_updatefreq" ] || [ "$ir" -lt "1" ] && break;
		echo -n '.'
		sleep 1
	done
fi
ir=$(ps | grep -v "grep" | grep -c "yamon$_file_version")
if [ "$ir" -gt "0" ]; then
	echo "$ir Zombie processes need to be killed?!?"
	echo "$(ps | grep -v 'grep' | grep 'yamon$_file_version')"
	while [ true ] ; do
		pid=$(ps | grep -v grep | grep yamon$_file_version | cut -d' ' -f1)
		[ -z "$pid" ] && break;
		[ "$o_pid" == "$pid" ] && "did not kill process: $pid ?!? try rebooting your router" && break
		kill $pid
		echo "killed process: $pid"
		sleep 1
		o_pid=$pid
	done
fi

echo "

$_s_stopped"