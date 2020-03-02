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

gt=$(top -n1)
ir=$(echo "$gt" | grep -v "grep" | grep -c "yamon")

if [ ! -d $_lockDir ] && [ "$ir" -eq "0" ]; then
    echo "$_s_notrunning"
    exit 0
elif [ -d $_lockDir ] && [ "$ir" -gt "0" ]; then
	rmdir $_lockDir
	echo "$_s_stopping"
	local n=0
	while [ true ] ; do
		n=$(($n + 1))
		gt=$(top -n1)
		ir=$(echo "$gt" | grep -v "grep" | grep -c "yamon")
		[ "$n" -gt "$_updatefreq" ] || [ "$ir" -lt "1" ] && break;
		echo -n '.'
		sleep 1
	done
fi
if [ "$ir" -gt "0" ]; then
    echo "$ir Zombie processes need to be killed?!?"
	while [ true ] ; do
		n=$(($n + 1))
		gt=$(top -n1)
		ir=$(echo "$gt" | grep -v "grep" | grep -c "yamon")
		[ "$n" -gt "$_updatefreq" ] || [ "$ir" -eq "0" ] && break;
        pid=$(ps | grep -v grep | grep yamon | cut -d' ' -f1)
        kill $pid
		echo "killed process: $pid"
		sleep 1
	done
fi

echo "

$_s_stopped"