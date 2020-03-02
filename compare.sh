#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
##########################################################################

directory='current'

getlatest()
{
	local path=$1
	spath="${path/.sh/.html}"
	local src="http://www.usage-monitoring.com/$directory/YAMon3/Setup/${spath}"
	local dst="${YAMON}/${path}"

	if [ -x /usr/bin/curl ] ; then
		curl -sk --max-time 15 -o "$dst" --header "Pragma: no-cache" --header "Cache-Control: no-cache" -A "YAMon-Setup" "$src"
	else
		wget "$src" -U "YAMon-Setup" -qO "$dst"
	fi
	if [ -f "$dst" ] ; then
		echo "   --> downloaded to $dst"
		local ext=$(echo -n $dst | tail -c 2)
		[ "$ext" == 'sh' ] && chmod 770 "$dst"
	else
		echo "   --> download failed?!?"
	fi
}

YAMON=`dirname $0`
_sync=''
[ -f "/tmp/files.txt" ] && rm "/tmp/files.txt"
arg=$1
[ ! -z "$arg" ] && arg="?bv=$arg"

wget "http://usage-monitoring.com/$directory/YAMon3/Setup/compare.php$arg" -U "YAMon-Setup" -qO "/tmp/files.txt"

echo "
**********************************
This script allows you to compare the md5 signatures of the files on
your router with the current versions at http://usage-monitoring.com.

You can choose to compare or synchronize the files
(i.e., replace any differing or missing on your router with
those at usage-monitoring.com).
"

resp=''
echo "Compare \`current\` or \`dev\` directories?
NB - normally you should pick \`current\`"
readstr="--> Enter \`d\` for \`dev\` or anything else for \`current\`:"
read -p "$readstr" resp
if [ "$resp" == 'd' ] || [ "$resp" == 'D' ] ; then
	directory='dev'
fi
echo "

***********************"
resp=''
echo "What would you like to do?"
readstr="--> Enter \`s\` to sync the files or anything else to just compare:"
read -p "$readstr" resp
if [ "$resp" == 's' ] || [ "$resp" == 'S' ] ; then
	_sync=1
fi
echo "

***********************"

n=0
spacing='                                                            '
needsRestart=''
allMatch=''
echo "
Comparing files...
   remote path: \`http://usage-monitoring.com/$directory/YAMon3/Setup/\`
    local path: \`$YAMON\`

   file                                 status
--------------------------------------------------"
while IFS=, read fn smd5
do
	path="$YAMON/$fn"
	n=$((n + 1))
	ts="$n. $fn:"
	pad=${spacing:0:$((32-${#ts}+1))}

	lmd5=$([ -f "$path" ] && echo $(md5sum "$path")| cut -d' ' -f1)
	echo -n "$ts"
	echo -n "$pad"
	if [ "$smd5" == "$lmd5" ] ; then
		echo "	matches"
		continue
	elif [ "$smd5" == "-" ] ; then
		echo "?!? not on server"
		continue
	elif [ ! -f "$path" ] && [ ! "$smd5" == "-" ] ; then
		sleep 1
		echo "*** missing ***"
		sleep 1
	else
		sleep 1
		echo "~~~ differs ($lmd5)"
		sleep 1
	fi
	allMatch=1
	[ "$_sync" == "1" ] && getlatest "$fn" && needsRestart=1
done < /tmp/files.txt
echo -n "--------------------------------------------------

Results:
* "
if [ "$needsRestart" == "1" ] ; then
	echo "One or more files were updated. Would you like to restart now?"
	readstr="--> Enter \`r\` to restart or anything else to exit: "
	read -p "$readstr" resp
	if [ "$resp" == 'r' ] || [ "$resp" == 'R' ] ; then
		${YAMON}/restart.sh 0
	else
		echo "You will have to manually restart soon."
	fi
elif [ -z "$allMatch" ] ; then
	echo "All of your files are up-to-date."
elif [ ! -z "$allMatch" ] ; then
	echo "One or more of your files is out-of-date and should be updated.
  Either re-run this script and hit \`s\` to sync all files, or
  visit \`http://usage-monitoring.com/manualInstall.php\` to update selectively."
fi

echo "
Send any questions or comments to questions@usage-monitoring.com

Thanks!

Al

"