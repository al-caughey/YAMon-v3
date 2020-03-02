##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# tally the hourly usage...
#
# 3.4.0 - substantial changes!
# 3.4.1 - added monthly totals
#
##########################################################################

#to do...  update last-seen in users.js

calcMonthlyTotal()
{
	toGB()
	{
		local in_gb=$(awk "BEGIN {printf \"%.2f\",${1}/1024/1024/1024}")
		local units=''
		[ -z "$2" ] && units=' GB'
		echo "$in_gb$units"
	}
	updateInDB()
	{
		$send2log "=== updateInDB  === " 0
		$send2log "Arguments: $1 / $2" -1
		local inGB=$(toGB $2)
		local srch="var ${1}=.*"
		local repl="var ${1}=\"${2}\"	// $inGB"
		sed -i "s~$srch~$repl~ w /tmp/sed.txt" $_macUsageDB
		##[ -s /tmp/sed.txt ] && $send2log "Did not replace $1?!?" 2
		[ -s /tmp/sed.txt ] && return
		$send2log "Could not update $1... not found in $_macUsageDB?!?" 2
	}
	getULTotals()
	{
		$send2log "=== getULTotals  === " 0
		billed_down=$(digitSub "$mt_down" "$mt_ul_down")
		billed_up=$(digitSub "$mt_up" "$mt_ul_up")
	}
	getTotals_0()
	{
		IFS=$'\n'
		for line in $(echo "$dgtl")
		do	
			mt_down=$(digitAdd $mt_down $(getCV "$line" 'down'))
			mt_up=$(digitAdd $mt_up $(getCV "$line" 'up'))
		done
		unset IFS
	}
	getTotals_1()
	{
		IFS=$'\n'
		for line in $(echo "$dgtl")
		do	
			mt_down=$(digitAdd $mt_down $(getCV "$line" 'down'))
			mt_up=$(digitAdd $mt_up $(getCV "$line" 'up'))
			mt_ul_down=$(digitAdd $mt_ul_down $(getCV "$line" 'ul_do'))
			mt_ul_up=$(digitAdd $mt_ul_up $(getCV "$line" 'ul_up'))
		done
		unset IFS
	}
	$send2log "=== calcMonthlyTotal  === " 0
	$send2log "Arguments: $1" -1

	mud=$(cat "$1")
	vars=$(echo "$mud" | grep '^var')
	dgtl=$(echo "$mud" | grep '^dgt(')

	$send2log "vars: $vars" -1
	$send2log "dgtl: $dgtl" -1
	local mt_down=0
	local mt_up=0
	local mt_ul_down=0
	local mt_ul_up=0
	local billed_down=0
	local billed_up=0
	
	eval "getTotals_$_unlimited_usage"
	
	$send2log "mt_down: $mt_down
	mt_up: $mt_up
	mt_ul_down: $mt_ul_down
	mt_ul_up: $mt_ul_up
	" -1
	
	if [ -z "$(echo $vars | grep 'monthly_total')" ] ; then
		local rotf=$(echo "$mud" | grep -v '^var')
		local mt="var monthly_total_down=\"\"
var monthly_total_up=\"\""
		if [ "$_unlimited_usage" -eq "1" ] ;  then
			mt="$mt
var monthly_unlimited_down=\"\"
var monthly_unlimited_up=\"\"
var monthly_billed_down=\"\"
var monthly_billed_up=\"\""
		fi
		echo "$vars
$mt
$rotf" > $_macUsageDB
	fi

	updateInDB "monthly_total_down" "$mt_down"
	updateInDB "monthly_total_up" "$mt_up"
	
	if [ "$_unlimited_usage" -eq "1" ] ;  then
		getULTotals
		updateInDB "monthly_unlimited_down" "$mt_ul_down"
		updateInDB "monthly_unlimited_up" "$mt_ul_up"
		updateInDB "monthly_billed_down" "$billed_down"
		updateInDB "monthly_billed_up" "$billed_up"
	fi
	
	updateInDB "monthly_updated" "$(date +"%Y-%m-%d %H:%M:%S")"
	
	local mt_tot=$(digitAdd $mt_up $mt_down)
	local mt_tot_gb=$(toGB $mt_tot 0)
	mcap=$_monthlyDataCap
	[ "$mcap" -eq "0" ] && mcap=1000
	local cd=$(date -d "$_pYear-$_pMonth-$_pDay" +'%j')
	local pom=$(awk "BEGIN {printf \"%.4f\",($cd-$sd+1)/($ed-$sd+1)*100}")
	local au=$(awk "BEGIN {printf \"%.0f\",100*($mt_tot_gb/$mcap)}")
	local emu=$(awk "BEGIN {printf \"%.0f\",10000*($mt_tot_gb/$mcap)/$pom}")
	$send2log "mt_tot_gb: $mt_tot_gb ($mt_up + $mt_down)
	mcap: $mcap GB
	cd: $cd ($_pYear-$_pMonth-$_pDay)
	sd: $sd ($rYear-$rMonth-$rday)
	ed: $ed ($eYear-$eMonth-$eday
	pom: $pom%
	au: $au
	emu: $emu GB" 0
	[ "$au" -gt "$mcap" ] && $send2log "Usage has exceeded your monthly cap!!! used: $au GB / cap: $_monthlyDataCap GB" 99 && return
	[ "$_monthlyDataCap" -eq "0" ] && [ "$emu" -gt 1000 ] && $send2log "Expected monthly usage could exceed 1TB ($emu GB)" 99 && return
	[ "$emu" -gt "$_monthlyDataCap" ] && $send2log "Expected monthly usage ($emu GB) could exceed your monthly cap of $_monthlyDataCap GB" 99 && return
	$send2log "Based upon usage to date, expected monthly total is ~$emu GB" 1 && return
}

updateHourly2Monthly()
{
	$send2log "=== updateHourly2Monthly === " 0
	
	setNewLine_0()
	{ 
		$send2log "=== setNewLine_0 === " 0
		echo "dt({\"mac\":\"$mac\",\"day\":\"$_pDay\",\"down\":$do_tot,\"up\":$up_tot})"
	}
	setNewLine_1()
	{ 
		$send2log "=== setNewLine_1 === " 0
		echo "dt({\"mac\":\"$mac\",\"day\":\"$_pDay\",\"down\":$do_tot,\"up\":$up_tot,\"ul_do\":$ul_do_tot,\"ul_up\":$ul_up_tot})"
	}
	getDGT_0()
	{ 
		$send2log "=== 	getDGT_0 === " 0
		echo "dgt({\"day\":\"$_pDay\",\"down\":$gt_down,\"up\":$gt_up})"
	}
	
	getDGT_1()
	{ 
		$send2log "=== getDGT_1 === " 0
		echo "dgt({\"day\":\"$_pDay\",\"down\":$gt_down,\"up\":$gt_up,\"ul_do\":$gt_ul_down,\"ul_up\":$gt_ul_up})"
	}
	
	tallyHourlyData_0()
	{	
		$send2log "=== tallyHourlyData_0 === " 0
		addUL_0()
		{
			$send2log "=== addUL_0  === " 0
			echo "$(setNewLine_0)"
		}
		
		addUL_1()
		{
			$send2log "=== addUL_1  === " 0
			ul_do_tot=$(digitAdd $(getCV "$curline" "ul_do") $(getCV "$line" "ul_do"))
			ul_up_tot=$(digitAdd $(getCV "$curline" "ul_up") $(getCV "$line" "ul_up"))

			if [ "$ul_do_tot" \< "0" ] ; then
				$send2log ">>> ul_do_tot rolled over --> $ul_do_tot" 0
				ul_do_tot=$(digitSub "$_maxInt" "$ul_do_tot")
			fi
			if [ "$ul_up_tot" \< "0" ] ; then
				$send2log ">>> ul_up_tot rolled over --> $ul_up_tot" 0
				ul_up_tot=$(digitSub "$_maxInt" "$ul_up_tot")
			fi
			gt_ul_down=$(digitAdd $gt_ul_down $ul_do_tot)
			gt_ul_up=$(digitAdd $gt_ul_up $ul_up_tot)
			echo "$(setNewLine_1)"
		}
		
		#old method, without uniq & sort
		local mac=''
		local hr=''
		local linematch=''
		local curline=''
		local woline=''
		local do_tot=0
		local up_tot=0
		local ul_do_tot=0
		local ul_up_tot=0
		local gt_down=0
		local gt_up=0
		local gt_ul_down=0
		local gt_ul_up=0
		local down=0
		local up=0

		IFS=$'\n'
		for line in $(echo "$hrlyData" | grep "^hu")
		do
			[ -z "$showProgress" ] || echo -n '.' >&2
			$send2log "line-->$line" 0
			mac=$(getField "$line" 'mac')
			mac=$(echo $mac | tr 'A-Z' 'a-z')
			hr=$(getField "$line" "hour")
			if [ -z "$mac" ] ; then
				$send2log "MAC is null?!?	$line" 2
				continue;
			fi
			linematch="dt({\"mac\":\"$mac\",\"day\":\"$_pDay\""
			curline=$(echo "$hr_results" | grep -i "$linematch")
			woline=$(echo "$hr_results" | grep -iv "$linematch")
			$send2log "curline-->$curline" -1

			down=$(getCV "$line" "down")
			up=$(getCV "$line" "up")
			do_tot=$(digitAdd $(getCV "$curline" "down") $down)
			up_tot=$(digitAdd $(getCV "$curline" "up") $up)

			gt_down=$(digitAdd $gt_down $down)
			gt_up=$(digitAdd $gt_up $up)

			if [ "$do_tot" \< "0" ] ; then
				$send2log ">>> do_tot rolled over --> $do_tot" 0
				do_tot=$(digitSub "$_maxInt" "$do_tot")
			fi
			if [ "$up_tot" \< "0" ] ; then
				$send2log ">>> up_tot rolled over --> $up_tot" 0
				up_tot=$(digitSub "$_maxInt" "$up_tot")
			fi
			newline="$(eval "addUL_$_unlimited_usage")"
			$send2log "newline-->$newline" -1
			hr_results="$woline
$newline"
		done
		[ -z "$showProgress" ] || echo '' >&2
		unset IFS

		dgt=$(eval $dgt_fn)
		hr_results="$hr_results
			
$dgt"

	}
	
	tallyHourlyData_1()
	{	#new method, with uniq & sort
		$send2log "=== tallyHourlyData_1  === " 0
	
		macTotals_0()
		{
			$send2log "=== macTotals_0  === " 0
			for line in $(echo "$macEntries") 
			do
				$send2log "line: $line" -1
				do_tot=$(digitAdd $do_tot $(getCV "$line" 'down'))
				up_tot=$(digitAdd $up_tot $(getCV "$line" 'up') )
			done
			newline=$(setNewLine_0)
			hr_results="$hr_results
$newline"
		}

		macTotals_1()
		{
			$send2log "=== macTotals_1  === " 0
			$send2log "macEntries: $macEntries" -1
			for line in $(echo "$macEntries") 
			do
				do_tot=$(digitAdd $do_tot $(getCV "$line" 'down'))
				up_tot=$(digitAdd $up_tot $(getCV "$line" 'up'))
				ul_do_tot=$(digitAdd $ul_do_tot $(getCV "$line" 'ul_do'))
				ul_up_tot=$(digitAdd $ul_up_tot $(getCV "$line" 'ul_up'))
			done
			gt_ul_down=$(digitAdd $gt_ul_down $ul_do_tot)
			gt_ul_up=$(digitAdd $gt_ul_up $ul_up_tot)
			
			echo "gt_ul_down: $gt_ul_down" &>2

			newline=$(setNewLine_1)
			hr_results="$hr_results
$newline"
		}
		
		local hrlyData=$(echo "$hrlyData" | grep "^hu")
		$send2log "hrlyData: $hrlyData " -1
		local macList=$(echo "$hrlyData" | grep -o '..:..:..:..:..:..' | tr 'A-Z' 'a-z' | sort -k1 | uniq -c | tr -s ' '| cut -d' ' -f3)
		$send2log "macList: $macList " -1
		IFS=$'\n'
		local gt_down=0
		local gt_up=0
		for mac in $(echo "$macList")
		do
			[ -z "$showProgress" ] || echo -n '.' >&2
			local down=0
			local up=0
			local do_tot=0
			local up_tot=0
			local ul_do_tot=0
			local ul_up_tot=0
			local macEntries=$(echo "$hrlyData" | grep -i $mac)

			eval "macTotals_"$_unlimited_usage

			gt_down=$(digitAdd $gt_down $do_tot )
			gt_up=$(digitAdd $gt_up $up_tot )

		done
		
		dgt=$(eval $dgt_fn)
		hr_results="$hr_results
			
$dgt"

	}
	
	$send2log "=== updateHourly2Monthly === " 0
	_pYear=$1
	_pMonth=$2
	_pDay=$3
	_pMonth=${_pMonth#0}
	local rMonth=${_pMonth#0}
	local eMonth=${_pMonth#0}
	local rYear=$_pYear
	local eYear=$_pYear
	local rday=$(printf %02d $_ispBillingDay)
	local eday=$(printf %02d $(($_ispBillingDay-1)))

	if [ "$_pDay" -lt "$_ispBillingDay" ] ; then
		rMonth=$(($rMonth-1))
		if [ "$rMonth" == "0" ] ; then
			rMonth=12
			rYear=$(($rYear-1))
		fi
	else
		eMonth=$(($_pMonth+1))
		if [ "$eMonth" == "13" ] ; then
			eMonth=1
			eYear=$(($eYear+1))
		fi
	fi
	_pMonth=$(printf %02d $_pMonth)
	rMonth=$(printf %02d $rMonth)
	eMonth=$(printf %02d $(($eMonth)))
	sd=$(date -d "$rYear-$rMonth-$rday" +'%j')
	ed=$(date -d "$eYear-$eMonth-$eday" +'%j')

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
		$send2log "*** Hourly usage file not found ($_prevhourlyUsageDB)  (_organizeData:$_organizeData)" 1
		return
	fi
	local pnd_results=''
	local p_do_tot=0
	local p_up_tot=0
	local _maxInt="4294967295"
	local hrlyData=$(cat "$_prevhourlyUsageDB")
	$send2log "hrlyData: $hrlyData" -1
	$send2log ">>> reading from $_prevhourlyUsageDB & writing to $_macUsageDB" 0

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
	[ -z "$showProgress" ] || echo -n "$_pYear-$_pMonth-$_pDay
	PND: " >&2
	for pnd in $(echo "$hrlyData" | grep "^pnd" | grep -v "\"start\"")
	do
		[ -z "$showProgress" ] || echo -n '.' >&2
		$send2log "pnd-->$pnd" -1
		hr=$(getCV "$pnd" "hour")
		uptime=$(getCV "$pnd" "uptime")
		down=$(getCV "$pnd" "down")
		up=$(getCV "$pnd" "up")
		$send2log "hr-->$hr  uptime-->$uptime  down-->$down  up-->up" 0
		if [ "$uptime" -ge "$p_uptime" ] ; then
			svd=$(digitSub "$down" "$p_pnd_d")
			svu=$(digitSub "$up" "$p_pnd_u")
			if [ "$svd" \< "0" ] ; then
				$send2log ">>> svd rolled over --> $svd" 0
				svd=$(digitSub "$_maxInt" "$svd")
			fi
			if [ "$svu" \< "0" ] ; then
				$send2log ">>> svu rolled over --> $svu" 0
				svu=$(digitSub "$_maxInt" "$svu")
			fi
		else
			svd=$down
			svu=$up
			nreboots=$(($nreboots + 1))
			$send2log ">>> Server rebooted... $hr - partial update	uptime:$uptime	p_uptime:$p_uptime	reboots:$nreboots" 2
		fi
		p_do_tot=$(digitAdd "$p_do_tot" "$svd")
		p_up_tot=$(digitAdd "$p_up_tot" "$svu")
		$send2log ">>> hr: $hr	uptime: $uptime	 p_uptime: $p_uptime	svd: $svd	svu: $svu " -1
		$send2log ">>> p_do_tot: $p_do_tot	p_up_tot: $p_up_tot " -1
		p_pnd_d=$down
		p_pnd_u=$up
		p_uptime=$uptime
	done
	unset IFS
	pnd_results="
dtp({\"day\":\"$_pDay\",\"down\":$p_do_tot,\"up\":$p_up_tot,\"reboots\":$nreboots})"
	save2File "$pnd_results" "$_macUsageDB" "append"

	local hr_results=''
	[ -z "$showProgress" ] || echo -n '
	Hourly: ' >&2

	dgt_fn="getDGT_$_unlimited_usage"
	eval "$tallyHourlyData"
	[ -z "$showProgress" ] || echo '' >&2
	save2File "$hr_results" "$_macUsageDB" "append"
	[ -z "$just" ] && calcMonthlyTotal "$_macUsageDB"
	
	$send2log "=== done updateHourly2Monthly === " 0
}