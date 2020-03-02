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
[ -z "$delay" ] && delay=5

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

if [ "${_logDir:0:1}" == "/" ] ; then
   _logfilename="${_logDir}/h2m.log"
else
   _logfilename="${d_baseDir}/${_logDir}/h2m.log"
fi 
_logfilename=${_logfilename//\/\//\/}
_configFile="${d_baseDir}/config.file"
_alertfilename="$_wwwPath${_wwwJS}alerts.js"

echo "_logfilename-->$_logfilename"
echo "_configFile-->$_configFile"
[ ! -f "$_logfilename" ] && touch "$_logfilename"
$send2log  "Log file:  \`$_logfilename\`." 1
$send2log "Loading baseline settings from \`$_configFile\`." 1

sleep $delay

echo "
In the prompts below, the recommended value is denoted with
an asterisk (*).  To accept this default, simply hit enter;
otherwise type your preferred value (and then hit enter).
"

zo_r=^[01]$


mo=$(date +%m)
rYear=$(date +%Y)
prompt 'mo' "Enter the month number of the reporting interval for which your are missing data:" '(Jan-->1, Feb-->2... Dec-->12)' "$mo" ^[1-9]$\|^[1][0-2]$ 'h2m'
prompt 'rYear' "Enter the year:" '' "$rYear" ^20[1-9][0-9]$ 'h2m'
prompt 'just' "Do you want to update the entire month or just one specific day?" 'Select 0 for the entire month or input the day number' "0" ^[0-9]$\|^[12][0-9]$\|^[3][01]$ 'h2m'
ap=0
[ "$just" -eq "0" ] && prompt 'ap' "Do you want to store the results in a new file or append them to the existing monthly data file?" 'Options: 0->New file(*) -or- 1->Append to existing' "0" $zo_r 'h2m'


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
		savePath="$_dataPath/$rYear/"
	;;
	(*"2"*)
		savePath="$_dataPath/$rYear/$rMonth/"
	;;
esac
savePath=${savePath//\/\//\/}

[ ! -d "$savePath" ] && mkdir -p "$savePath"

if [ "$ap" -eq "0" ] ; then
	fn=$(echo "$_usageFileName" | cut -d'.' -f1)
	_usageFileName="${fn}2.js"
fi

if [ -z "$(which sort)" ] || [ -z "$(which uniq)" ] ; then
	tallyHourlyData="tallyHourlyData_0"
else
	tallyHourlyData="tallyHourlyData_1"
fi

_macUsageDB="$savePath$rYear-$rMonth-$_usageFileName"
ds=$(date +"%Y-%m-%d %H:%M:%S")
if [ ! -f "$_macUsageDB" ] ; then
	touch $_macUsageDB
	echo "var monthly_created=\"$ds\"
var monthly_updated=\"$ds\"
var monthlyDataCap=\"$_monthlyDataCap\"" > $_macUsageDB
fi

echo "
========================================================

Processing data files for billing interval: $rYear-$rMonth-$rDay"
echo ">>> saving to: $_macUsageDB"

showProgress=1

# Set nice level to 10 of current PID (low priority)
if [ -z "$(which renice)" ] ; then 
	$send2log ">>> Setting renice does not exist in this firmware" 1
else
	$send2log ">>> Setting renice level to 10 on PID: $$" 1
	renice 10 $$
fi

if [ "$just" -ne "0" ] ; then
	while [ 1 ] ; do
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
		updateHourly2Monthly "$jy" "$jm" "$jd"
		just=0
		prompt 'just' "Do you want to update another day?" 'Select 0 for `no` or input the day number' "0" ^[0-9]$\|^[12][0-9]$\|^[3][01]$ 'h2m'
		[ "$just" -eq "0" ] && break
	done 
	calcMonthlyTotal "$_macUsageDB"
else

	i=$_ispBillingDay
	while [  "$i" -le "31" ] ; do
		cm=$(date +"%m" "$rYear-${rMonth#0}-$i")
		d=$(printf %02d $i)
		[ "$cm" == "$rMonth" ] && updateHourly2Monthly "$rYear" "${rMonth#0}" "$d"
		i=$(($i+1))
	done
	$send2log ">>> Finished to end of month" 1

	if [ "$rMonth" -eq "12" ]; then
		rMonth='01'
		rYear=$(($rYear+1))
	else
		nm=$(($rMonth+1))
		rMonth=$(printf %02d $nm)
	fi

	i=1
	while [  $i -lt "$_ispBillingDay" ] ; do
		d=$(printf %02d $i)
		updateHourly2Monthly "$rYear" "${rMonth#0}" "$d"
		i=$(($i+1))
	done
	$send2log ">>> Finished start to end of next interval" 1

	ds=$(date +"%Y-%m-%d %H:%M:%S")
	calcMonthlyTotal "$_macUsageDB"
fi
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
