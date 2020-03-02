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

source "$d_baseDir/includes/defaults.sh"
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
if [ -d $_lockDir ] ; then
	rmdir $_lockDir
	echo "$_s_stopping"
	local n=0
	while [ true ] ; do
		n=$(($n + 1))
		gt=$(top -n1)
		ir=$(echo "$gt" | grep "yamon3")
		[ "$n" -gt "$_updatefreq" ] || [ -z "$ir" ] && break;
		echo -n '.'
		sleep 1
	done
	echo "$_s_stopped"
else
	echo "$_s_notrunning"
fi