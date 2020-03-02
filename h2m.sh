#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  re-aggregate monthly data from the hourly file
#
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)
delay=$1
[ -z $delay ] && delay=5

source "$d_baseDir/config.file"
source "${d_baseDir}/includes/versions.sh"
source "$d_baseDir/includes/util$_version.sh"
source "${d_baseDir}/includes/defaults.sh"
source "${d_baseDir}/strings/$_lang/strings.sh"

source "${d_baseDir}/includes/hourly2monthly.sh"

_cYear=$(date +%Y)
_cDay=$(date +%d)
_cMonth=$(date +%m)
_ds="$_cYear-$_cMonth-$_cDay"

clear
echo "$_s_title"
echo "
******************************************************************

This script will fill missing data gaps in your monthly usage file.

******************************************************************
"

sleep $delay

_logfilename="${d_baseDir}/$_logDir"'h2m.log'
echo "_logfilename-->$_logfilename"
[ ! -f "$_logfilename" ] && touch "$_logfilename"
$send2log  "Log file:  \`$_logfilename\`." 1
$send2log "Loading baseline settings from \`$_configFile\`." 2

sleep $delay

echo "
In the prompts below, the recommended value is denoted with
an asterisk (*).  To accept this default, simply hit enter;
otherwise type your preferred value (and then hit enter).
"

yn_y="Options: 0->No -or- 1->Yes(*)"
yn_n="Options: 0->No(*) -or- 1->Yes"
zo_r=^[01]$
zot_r=^[012]$

mo=$(date +%m)
rYear=$(date +%Y)
prompt 'mo' "Enter the month number of the reporting interval for which your are missing data:" '(Jan-->1, Feb-->2... Dec-->12)' "$mo" ^[1-9]$\|^[1][0-2]$
prompt 'rYear' "Enter the year:" '' "$rYear" ^20[1-9][0-9]$
prompt 'just' "Do you want to update the entire month or just one specific day?" 'Select 0 for the entire month or input the day number' "0" ^[0-9]$\|^[12][0-9]$\|^[3][01]$
ap=0
[ "$just" -eq "0" ] && prompt 'ap' "Do you want to store the results in a new file or append them to the existing monthly data file?" 'Options: 0->New file(*) -or- 1->Append to existing' "0" $zo_r


mo=${mo#0}
rDay=$(printf %02d $_ispBillingDay)
rMonth=$(printf %02d $mo)

if [ "${_dataDir:0:1}" == "/" ] ; then
	_dataPath=$_dataDir
else
	_dataPath="${d_baseDir}/$_dataDir"
fi
case $_organizeData in
	(*"0"*)
		savePath="$_dataPath"
	;;
	(*"1"*)
		savePath="$_dataPath$rYear/"
	;;
	(*"2"*)
		savePath="$_dataPath$rYear/$rMonth/"
	;;
esac

[ ! -d "$savePath" ] && mkdir -p "$savePath"

if [ "$ap" -eq "0" ] ; then
	fn=$(echo "$_usageFileName" | cut -d'.' -f1)
	_usageFileName="${fn}2.js"
fi

#_macUsageDB="$savePath$rYear-$rMonth-$rDay-$_usageFileName"
_macUsageDB="$savePath$rYear-$rMonth-$_usageFileName"
ds=$(date +"%Y-%m-%d %H:%M:%S")
if [ ! -f "$_macUsageDB" ] ; then
	touch $_macUsageDB
	echo "var monthly_created=\"$ds\"
var monthly_updated=\"$ds\"" > $_macUsageDB
fi

echo "
========================================================

Processing data files for billing interval: $rYear-$rMonth-$rDay"
echo ">>> saving to: $_macUsageDB"
if [ "$just" -ne "0" ] ; then
	jd=$(printf %02d $just)
	jm=$mo
	jy=$rYear
	if [ "$just" -lt "$_ispBillingDay" ] ; then
		if [ "$mo" -eq "12" ]; then
			jm='01'
			jy=$(($rYear+1))
		else
			jm=$(($mo+1))
			jm=$(printf %02d $jm)
		fi
	fi
	echo ">>> just: $jy-$jm-$jd"
fi

showProgress=1

i=$_ispBillingDay
while [  "$i" -le "31" ]; do
	[ "$just" -ne "0" ] && [ "$just" -ne "$i" ] && i=$(($i+1)) && continue

	d=$(printf %02d $i)
	updateHourly2Monthly "$rYear" "${rMonth#0}" "$d"
	i=$(($i+1))
done

$send2log ">>> Finished to end of month" 2
if [ "$mo" -eq "12" ]; then
	rMonth='01'
	rYear=$(($rYear+1))
else
	nm=$(($mo+1))
	rMonth=$(printf %02d $nm)
fi

i=1
while [  $i -lt "$_ispBillingDay" ]; do
	[ "$just" -ne "0" ] && [ "$just" -ne "$i" ] && i=$(($i+1)) && continue
	d=$(printf %02d $i)
	updateHourly2Monthly "$rYear" "$rMonth" "$d"
	i=$(($i+1))
done
$send2log ">>> Finished start to end of next interval" 2

ds=$(date +"%Y-%m-%d %H:%M:%S")
sed -i "s~var monthly_updated=.*~var monthly_updated=\"$ds\"~" $_macUsageDB
echo "

=== Done updateHourly2Monthly ===

Note: the new monthly usage file has been named *.$_usageFileName..."
[ "$ap" -eq "0" ] && echo "
You must rename this file before the data can be used by the reports or
copy and paste the data from this file into your active monthly usage
file.

NB - you do *not* have to stop the main script to copy the data from
the new file into your active hourly data file.

"
