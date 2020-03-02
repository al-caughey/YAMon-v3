##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# tally the hourly usage...
#
##########################################################################

#to do...  update last-seen in users.js

updateHourly2Monthly()
{
	$send2log "=== updateHourly2Monthly === " 0
	local _pYear=$1
	local _pMonth=$2
	local _pDay=$3
	local _pMonth=${_pMonth#0}
	local rMonth=${_pMonth#0}
	local rYear=$_pYear
	local rday=$(printf %02d $_ispBillingDay)

	if [ "$_pDay" -lt "$_ispBillingDay" ] ; then
		local rMonth=$(($rMonth-1))
		if [ "$rMonth" == "0" ] ; then
			rMonth=12
			local rYear=$(($rYear-1))
		fi
	fi
	_pMonth=$(printf %02d $_pMonth)
	rMonth=$(printf %02d $rMonth)

	if [ "${_dataDir:0:1}" == "/" ] ; then
		local _dataPath=$_dataDir
	else
		local _dataPath="${d_baseDir}/$_dataDir"
	fi
	case $_organizeData in
		(*"0"*)
			local savePath="$_dataPath"
		;;
		(*"1"*)
			local savePath="$_dataPath$rYear/"
		;;
		(*"2"*)
			local savePath="$_dataPath$rYear/$rMonth/"
		;;
	esac
	#_macUsageDB="$savePath$rYear-$rMonth-$rday-$_usageFileName"
	_macUsageDB="$savePath$rYear-$rMonth-$_usageFileName"
	[ "$_enable_ftp" -eq "1" ] && _macUsageFTP="$_cYear-$_cMonth-$_cDay-$_usageFileName"

	local _prevhourlyUsageDB="$savePath$_pYear-$_pMonth-$_pDay-$_hourlyFileName"
	if [ ! -f "$_prevhourlyUsageDB" ]; then
		$send2log "*** Hourly usage file not found ($_prevhourlyUsageDB)  (_organizeData:$_organizeData)" 2
		return
	fi
	local results=''
	local p_do_tot=0
	local p_up_tot=0
	local _maxInt="4294967295"
	local hrlyData=$(cat "$_prevhourlyUsageDB")
	$send2log "  >>> reading from $_prevhourlyUsageDB & writing to $_macUsageDB" 0

	local hr=''
	local nreboots=0
	local down=0
	local up=0
	local uptime=0

	local pnd=$(echo "$hrlyData" | grep -i '"start"')
	local p_uptime=$(getCV "$pnd" "uptime")
	local p_pnd_d=$(getCV "$pnd" "down")
	local p_pnd_u=$(getCV "$pnd" "up")
	$send2log "Initial: p_uptime-->$p_uptime  p_pnd_d-->$p_pnd_d  p_pnd_u-->$p_pnd_u" -1
	IFS=$'\n'
	[ ! -z "$showProgress" ] && echo -n '
	PND: ' >&2
	for pnd in $(echo "$hrlyData" | grep "^pnd" | grep -v "\"start\"")
	do
		[ ! -z "$showProgress" ] && echo -n '.' >&2
		$send2log "  pnd-->$pnd" -1
		hr=$(getCV "$pnd" "hour")
		uptime=$(getCV "$pnd" "uptime")
		down=$(getCV "$pnd" "down")
		up=$(getCV "$pnd" "up")
		$send2log "  hr-->$hr  uptime-->$uptime  down-->$down  up-->up" 0
		if [ "$uptime" -ge "$p_uptime" ] ; then
			svd=$(digitSub "$down" "$p_pnd_d")
			svu=$(digitSub "$up" "$p_pnd_u")
			if [ "$svd" \< "0" ] ; then
				$send2log "  >>> svd rolled over --> $svd" 0
				svd=$(digitSub "$_maxInt" "$svd")
			fi
			if [ "$svu" \< "0" ] ; then
				$send2log "  >>> svu rolled over --> $svu" 0
				svu=$(digitSub "$_maxInt" "$svu")
			fi
		else
			svd=$down
			svu=$up
			nreboots=$(($nreboots + 1))
			$send2log "  >>> Server rebooted... $hr - partial update /tuptime:$uptime	p_uptime:$p_uptime	nreboots:$nreboots" 2
		fi
		p_do_tot=$(digitAdd "$p_do_tot" "$svd")
		p_up_tot=$(digitAdd "$p_up_tot" "$svu")
		$send2log "  >>> hr: $hr	uptime: $uptime	 p_uptime: $p_uptime	svd: $svd	svu: $svu " -1
		$send2log "  >>> p_do_tot: $p_do_tot	p_up_tot: $p_up_tot " -1
		p_pnd_d=$down
		p_pnd_u=$up
		p_uptime=$uptime
	done
	unset IFS
	[ ! -z "$showProgress" ] && echo '' >&2
	results="
dtp({\"day\":\"$_pDay\",\"down\":$p_do_tot,\"up\":$p_up_tot,\"reboots\":$nreboots})"

	local mac=''
	local hr=''
	local linematch=''
	local curline=''
	local woline=''
	IFS=$'\n'
	[ ! -z "$showProgress" ] && echo -n '
	Hourly: ' >&2
	for line in $(echo "$hrlyData" | grep "^hu")
	do
		[ ! -z "$showProgress" ] && echo -n '.' >&2
		$send2log "  line-->$line" 0
 		mac=$(getField "$line" 'mac')
		hr=$(getField "$line" "hour")
		if [ -z "$mac" ] ; then
			$send2log "MAC is null?!?	$line" 2
			continue;
		fi
		linematch="dt({\"mac\":\"$mac\",\"day\":\"$_pDay\""
		curline=$(echo "$results" | grep -i "$linematch")
		woline=$(echo "$results" | grep -iv "$linematch")
		$send2log "  curline-->$curline" -1

		do_tot=$(digitAdd $(getCV "$curline" "down") $(getCV "$line" "down"))
		up_tot=$(digitAdd $(getCV "$curline" "up") $(getCV "$line" "up"))
		if [ "$do_tot" \< "0" ] ; then
			$send2log "  >>> do_tot rolled over --> $do_tot" 0
			do_tot=$(digitSub "$_maxInt" "$do_tot")
		fi
		if [ "$up_tot" \< "0" ] ; then
			$send2log "  >>> up_tot rolled over --> $up_tot" 0
			up_tot=$(digitSub "$_maxInt" "$up_tot")
		fi
		if [ "$_unlimited_usage" -eq "0" ] ; then
			newline=$(setNewLine $mac $_pDay $do_tot $up_tot)
		else
			ul_do_tot=$(digitAdd $(getCV "$curline" "ul_do") $(getCV "$line" "ul_do"))
			ul_up_tot=$(digitAdd $(getCV "$curline" "ul_up") $(getCV "$line" "ul_up"))
			newline=$(setNewLineUL $mac $_pDay $do_tot $up_tot $ul_do_tot $ul_up_tot)
		fi
		$send2log "  newline-->$newline" -1
		results="$woline
$newline"
	done
	[ ! -z "$showProgress" ] && echo '' >&2
	unset IFS
	save2File "$results" "$_macUsageDB" "append"

	$send2log "  results for: $_pYear-$_pMonth-$_pDay
$results" 0
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	#[ "$_symlink2data" -eq "0" ] && copyfiles "$_macUsageDB" "$_macUsageWWW"

	$send2log "=== done updateHourly2Monthly === " 0
}
setNewLine(){
	echo "dt({\"mac\":\"$1\",\"day\":\"$2\",\"down\":$3,\"up\":$4})"
}
setNewLineUL(){
	echo "dt({\"mac\":\"$1\",\"day\":\"$2\",\"down\":$3,\"up\":$4,\"ul_do\":$5,\"ul_up\":$6})"
}
digitAdd()
{
	local n1=$1
	local n2=$2
	local l1=${#n1}
	local l2=${#n2}
	[ -z "$n1" ] && n1=0
	[ -z "$n2" ] && n2=0
	if [ "$l1" -lt "10" ] && [ "$l2" -lt "10" ] ; then
		total=$(($n1+$n2))
		echo $total
		return
	fi
	local carry=0
	local total=''
	while [ "$l1" -gt "0" ] || [ "$l2" -gt "0" ]; do
		d1=0
		d2=0
		l1=$(($l1-1))
		l2=$(($l2-1))
		[ "$l1" -ge "0" ] && d1=${n1:$l1:1}
		[ "$l2" -ge "0" ] && d2=${n2:$l2:1}
		s=$(($d1+$d2+$carry))
		sum=$(($s%10))
		carry=$(($s/10))
		total="$sum$total"
	done
	[ "$carry" -eq "1" ] && total="$carry$total"
	[ -z "$total" ] && total=0
	echo $total
}
digitSub()
{
	local n1=$(echo "$1" | sed 's/-*//')
	local n2=$(echo "$2" | sed 's/-*//')
	[ -z "$n1" ] && n1=0
	[ -z "$n2" ] && n2=0
	if [ "$n1" == "$n2" ] ; then
		echo 0
		return
	fi
	local l1=${#n1}
	local l2=${#n2}
	if [ "$l1" -lt "10" ] && [ "$l2" -lt "10" ] ; then
		echo $(($n1-$n2))
		return
	fi
	local b=0
	local total=''
	local d1=0
	local d2=0
	local d=0
	while [ "$l1" -gt "0" ] || [ "$l2" -gt "0" ]; do
		d1=0
		d2=0
		l1=$(($l1-1))
		l2=$(($l2-1))
		[ "$l1" -ge "0" ] && d1=${n1:$l1:1}
		[ "$l2" -ge "0" ] && d2=${n2:$l2:1}
		[ "$d2" == "-" ] && d2=0
		d1=$(($d1-$b))
		b=0
		[ $d2 -gt $d1 ] && b="1"
		d=$(($d1+$b*10-$d2))
		total="$d$total"
	done
	[ "$b" -eq "1" ] && total="-$total"
	echo $(echo "$total" | sed 's/0*//')
}