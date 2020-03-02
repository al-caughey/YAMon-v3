#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  Call this file from the Administration-->Commands tab in the DD-WRT GUI
#
# NEW: by default this script will delay for 10 seconds before launching
#	  yamon###.sh... you can shorten or lengthen the delay via a parameter
#	  e.g., >>> startup.sh 0
#		 or >>> startup.sh 30
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

np=$(ps | grep -v grep | grep -c yamon$_file_version)
if [ "$np" -gt "0" ] || [ -d "$_lockDir" ] ; then
	echo "$_s_running"
	exit 0
fi
# wait for a bit (10 seconds)... depending on your router you can make this longer or shorter
delay=$1
[ -z $delay ] && delay=10

echo "
$los
YAMon will be started following a delay of $delay seconds.

NB - depending on your router and firmware, you may have to increase
	 this delay (to allow  other processes to startup properly),
	 or you may be able to eliminate the delay altogether.
$los
"
i=0
while [ $i -lt $delay ] ; do
  echo -n '.'
  sleep 1
  i=$(($i + 1))
done

[ -x /usr/bin/clear ] && clear
# launch the script
${d_baseDir}/yamon${_version}.sh &
