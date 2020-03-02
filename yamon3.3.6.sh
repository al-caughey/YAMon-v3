#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  See <http://www.usage-monitoring.com/license/> for a copy of the
#  GNU General Public License or see <http://www.gnu.org/licenses/>.
#
##########################################################################

#HISTORY
# 3.3.0 (2017-06-18): bumped minor version; added xwrt
# 3.3.1 (2017-07-17): added option for ip_conntrack vs nf_conntrack; added count number to new devices; added defensive code to better handle oddball situations where iptables chains go missing
#                     added setupIPChains; changes in setFirmware, CheckUsersJS, update
#                     general housekeeping; removed blocks of unused code; tweaked some regexes
# 3.3.2 (2017-07-19): replaced `command` with `which`; removed ls -e; some Tomato fixes
# 3.3.3 (2017-09-25): tidied up d_baseDir; monthly files are now year-mo (without date); added option to archive live updates
# 3.3.4 (2017-10-11): fixed issues in setup.sh; fixed _liveFilePath
# 3.3.6 (2017-11-17): fixed addLocalIPs
# ==========================================================
#				  Functions
# ==========================================================
setupIPChains(){
	$send2log "=== setupIPChains ($cmd/$rule) === " 2
    checkChain(){
        local cmd="$1"
        local chain="$2"
        local ce=$(echo "$ipchains" | grep "$chain\b")
        if [ -z "$ce" ] ; then
            $send2log "Adding $chain in $cmd ($_tMangleOption)" 2
            eval $cmd $_tMangleOption -N $chain
        else 
            send2log "$chain exists in $cmd ($_tMangleOption)" 0
        fi
    }
    addLocalIPs(){
        local cmd="$1"
        local chain="$2"
        local ip_blocks="$3"
        local generic="$4"
        eval $cmd $_tMangleOption -F "$chain"
        eval $cmd $_tMangleOption -F "${chain}Entry"
        eval $cmd $_tMangleOption -F "${chain}Local"
    	IFS=$','
        for iprs in $(echo "$ip_blocks")
        do
            for iprd in $(echo "$ip_blocks")
            do
                eval $cmd $_tMangleOption -I "${chain}Entry" -j "RETURN" -s $iprs -d $iprd
                eval $cmd $_tMangleOption -I "${chain}Entry" -j "${chain}Local" -s $iprs -d $iprd
            done
        done
        eval $cmd $_tMangleOption -A "${chain}Entry" -j "${chain}"
        eval $cmd $_tMangleOption -I "${chain}Local" -j "RETURN" -s $generic -d $generic
        eval $cmd $_tMangleOption -A "$chain" -j "RETURN" -s $generic -d $generic
        IFS=$'\n'
    }
	ipchains=$(eval iptables $_tMangleOption -L -vnx | grep Chain)
    checkChain 'iptables' "$YAMON_IP4"
    checkChain 'iptables' "${YAMON_IP4}Entry"
    checkChain 'iptables' "${YAMON_IP4}Local"

    addLocalIPs 'iptables' "$YAMON_IP4" "$_PRIVATE_IP4_BLOCKS" "$_generic_ipv4" 
    
	checkIPChain "iptables" "FORWARD" "$YAMON_IP4"
	checkIPChain "iptables" "INPUT" "$YAMON_IP4"
	checkIPChain "iptables" "OUTPUT" "$YAMON_IP4"
	
	local nm=$(eval iptables $_tMangleOption -vnxL "$YAMON_IP4" | grep -c "\b$_generic_ipv4\b")
	checkIPTableEntries "iptables" "$YAMON_IP4" "$_generic_ipv4" $nm
	
	if [ ! -z "$_lan_ipaddr" ] ; then
		local nm=$(eval iptables $_tMangleOption -vnxL "$YAMON_IP4" | grep -c "\b$_lan_ipaddr\b")
		checkIPTableEntries "iptables" "$YAMON_IP4" "$_lan_ipaddr" $nm
	fi
	if [ ! -z "$_wan_ipaddr" ] ; then
		local nm=$(eval iptables $_tMangleOption -vnxL "$YAMON_IP4" | grep -c "\b$_wan_ipaddr\b")
		checkIPTableEntries "iptables" "$YAMON_IP4" "$_wan_ipaddr" $nm
	fi
    
	if [ "$_includeIPv6" -eq "1" ] ; then
		_getIP6List="$_path2ip -6 neigh | grep 'lladdr' | cut -d' ' -f1,5 | tr '[A-Z]' '[a-z]' $sortStr"

        ipchains=$(eval ip6tables $_tMangleOption -L -vnx | grep Chain)
        checkChain 'ip6tables' "$YAMON_IP6"
        checkChain 'ip6tables' "${YAMON_IP6}Entry"
        checkChain 'ip6tables' "${YAMON_IP6}Local"

        addLocalIPs 'ip6tables' "$YAMON_IP6" "$_PRIVATE_IP6_BLOCKS" "$_generic_ipv6"
    
		checkIPChain 'ip6tables' 'FORWARD' "$YAMON_IP6"
		checkIPChain 'ip6tables' 'INPUT' "$YAMON_IP6"
		checkIPChain 'ip6tables' 'OUTPUT' "$YAMON_IP6"
		
		local nm=$(eval ip6tables $_tMangleOption -vnxL "$YAMON_IP6" | grep -c "\b$_generic_ipv6\b")
		checkIPTableEntries "ip6tables" "$YAMON_IP6" "$_generic_ipv6" $nm

		[ ! -z "$_lan_ip6addr" ] && checkIPTableEntries "ip6tables" "$YAMON_IP6" "$_lan_ip6addr" 0
	fi

}
setInitValues(){

	_configFile="$d_baseDir/config.file"
	source "$_configFile"

	[ -z $(which ftpput) ] && [ "$_enable_ftp" -eq 1 ] && _enable_ftp=0 && echo "
*** _enable_ftp set to 0 because command ftpput was not found?!?
*** Please check your config.file
"

	source "$d_baseDir/strings/$_lang/strings.sh"
	_savedconfigMd5=$(md5sum $_configFile | cut -f1 -d" ")
	setLogFile

	setFirmware
	setupIPChains
    
	updateServerStats
	setDataDirectories
	setWebDirectories
	setUsers
	setConfigJS
	[ ! -d "$_lockDir" ] && mkdir "$_lockDir"
	local ts=$(date +"%H:%M:%S")
	if [ "$started" -eq "0" ] ; then
		echo "$_s_started"
		if [ "$_doLocalFiles" -gt "0" ] ; then
			source "$d_baseDir/includes/getLocalCopies.sh"
			getLocalCopies
		fi
		$send2log "YAMon was started at $ts" 99
	fi
	local meminfo=$(cat /proc/meminfo)
	_totMem=$(getMI "$meminfo" "MemTotal")

	local sortStr=''
	local cansort=$(echo "$(which sort)")
	[ ! -z "$canSort" ] && sortStr=" | sort -k2"

	local p2ip=$(which ip)
	if [ -z "$p2ip" ] ; then
		_getIP4List="cat /proc/net/arp | grep '^[0-9]' | grep -v '00:00:00:00:00:00' | tr -s ' ' | cut -d' ' -f1,4 | tr '[A-Z]' '[a-z]' $sortStr"
	else
		local tip=$(echo "$($p2ip -4 neigh show)")
		if [ -z "$tip" ] ; then
			_getIP4List="cat /proc/net/arp | grep '^[0-9]' | grep -v '00:00:00:00:00:00' | tr -s ' ' | cut -d' ' -f1,4 | tr '[A-Z]' '[a-z]' $sortStr"
		else
			_getIP4List="$p2ip -4 neigh | grep 'lladdr' | cut -d' ' -f1,5 | tr '[A-Z]' '[a-z]' $sortStr"
		fi
	fi
	_usersLastMod=$(date -r "$_usersFile" "+%Y-%d-%m %T")
	started=1
}
setLogFile()
{
	if [ "${_logDir:0:1}" == "/" ] ; then
		local lfpath=$_logDir
	else
		local lfpath="${d_baseDir}/$_logDir"
	fi
	[ ! -d "$lfpath" ] && mkdir -p "$lfpath"
	_logfilename="${lfpath}monitor$_version-$_cYear-$_cMonth-$_cDay.log"
	[ ! -f "$_logfilename" ] && touch "$_logfilename" && $send2log "YAMon :: version $_version	_loglevel: $_loglevel" 2
	$send2log "=== setLogFile ===" -1
	$send2log "Installed firmware: $installedfirmware $installedversion $installedtype" 2
}
setDataDirectories()
{
	$send2log "=== setDataDirectories ===" -1
	local rMonth=${_cMonth#0}
	local rYear="$_cYear"
	local rday=$(printf %02d $_ispBillingDay)
	if [ "$_cDay" -lt "$_ispBillingDay" ] ; then
		rMonth=$(($rMonth-1))
		if [ "$rMonth" == "0" ] ; then
			rMonth=12
			rYear=$(($rYear-1))
		fi
	fi
	rMonth=$(printf %02d $rMonth)
	if [ "${_dataDir:0:1}" == "/" ] ; then
		_dataPath=$_dataDir
	else
		_dataPath="${d_baseDir}/$_dataDir"
	fi
	$send2log "  >>> _dataPath --> $_dataPath" 0
	if [ ! -d "$_dataPath" ] ; then
		$send2log "  >>> Creating data directory" 0
		mkdir -p "$_dataPath"
		chmod -R 666 "$_dataPath"
	fi
	case $_organizeData in
		(*"0"*)
			local savePath="$_dataPath"
			local wwwsavePath="$_wwwPath$_wwwData"
		;;
		(*"1"*)
			local savePath="$_dataPath$rYear/"
			local wwwsavePath="$_wwwPath$_wwwData$rYear/"
		;;
		(*"2"*)
			local savePath="$_dataPath$rYear/$rMonth/"
			local wwwsavePath="$_wwwPath$_wwwData$rYear/$rMonth/"
		;;
	esac
	if [ ! -d "$savePath" ] ; then
		$send2log "  >>> Adding data directory - $savePath " 0
		mkdir -p "$savePath"
		chmod -R 666 "$savePath"
	else
		$send2log "  >>> data directory exists - $savePath " -1
	fi
	if [ "$_symlink2data" -eq "0" ] && [ ! -d "$wwwsavePath" ] ; then
		$send2log "  >>> Adding web directory - $wwwsavePath " 0
		mkdir -p "$wwwsavePath"
		chmod -R 666 "$wwwsavePath"
	else
		$send2log "  >>> web directory exists - $wwwsavePath " -1
	fi

	[ "$_symlink2data" -eq "0" ] &&  [ "$(ls -A $_dataPath)" ] && copyfiles "$_dataPath*" "$_wwwPath$_wwwData"
	_macUsageDB="$savePath$rYear-$rMonth-$_usageFileName"
	_macUsageWWW="$wwwsavePath$rYear-$rMonth-$rday-$_usageFileName"
	local old_macUsageDB="$savePath$rYear-$rMonth-$rday-$_usageFileName"
	if [ -f "$_macUsageDB" ] ; then
		$send2log "  _macUsageDB exists--> $_macUsageDB" 2
	elif [ -f "$old_macUsageDB" ] ; then
		$send2log "  copying $old_macUsageDB --> $_macUsageDB" 2
		$(cp -a $old_macUsageDB $_macUsageDB)
	else
		createMonthlyFile
	fi
	
	[ ! -d "$_wwwPath$_wwwJS" ] && mkdir -p "$_wwwPath$_wwwJS"
	
	if [ "$_doLiveUpdates" -eq "1" ] ; then
		_liveFilePath="$_wwwPath$_wwwJS$_liveFileName"
		if [ ! -f "$_liveFilePath" ] ; then
			touch $_liveFilePath
			chmod 666 $_liveFilePath
		fi
		if [ "$_doArchiveLiveUpdates" -eq "1" ] ; then
			_liveArchiveFilePath="$wwwsavePath$_cYear-$_cMonth-$_cDay-$_liveFileName"
			if [ ! -f "$_liveArchiveFilePath" ] ; then
				touch $_liveArchiveFilePath
				chmod 666 $_liveArchiveFilePath
			fi
		fi
	fi
	
	_hourlyUsageDB="$savePath$_cYear-$_cMonth-$_cDay-$_hourlyFileName"
	_hourlyUsageWWW="$wwwsavePath$_cYear-$_cMonth-$_cDay-$_hourlyFileName"

	[ ! -f "$_hourlyUsageDB" ] && createHourlyFile
	local hd=$(cat "$_hourlyUsageDB")
	local hdhu=$(echo "$hd" | grep '^hu' )
	local hdpd=$(echo "$hd" | grep '^pnd' )
	_hourlyCreated=$(echo "$hd" | grep '^var hourly_created')
	local hr=$(date +"%H")
	_hourlyData=$(echo "$hdhu" | grep -v "\"hour\":\"$hr\"")
	_thisHrdata=$(echo "$hdhu" | grep "\"hour\":\"$hr\"")
	_pndData=$(echo "$hdpd" | grep -v "\"hour\":\"$hr\"")
	_thisHrpnd=$(echo "$hdpd" | grep "\"hour\":\"$hr\"")
	$send2log "  _hourlyData--> $_hourlyData" -1
	$send2log "  _thisHrdata ($hr)--> $_thisHrdata" 0
	$send2log "  _pndData--> $_pndData" -1
	$send2log "  _thisHrpnd ($hr)--> $_thisHrpnd" 0
}
createMonthlyFile()
{
	$send2log "=== createMonthlyFile ===" -1
	$send2log "  >>> Monthly usage file not found... creating new file: $_macUsageDB" 2
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	touch $_macUsageDB
	chmod 666 $_macUsageDB
	local nmf="var monthly_created=\"$ds\"
var monthly_updated=\"$ds\""
	save2File "$nmf" "$_macUsageDB"

	[ "$_symlink2data" -eq "0" ] && copyfiles "$_macUsageDB" "$_macUsageWWW"

}
createHourlyFile()
{
	$send2log "=== createHourlyFile ===" -1
	touch $_hourlyUsageDB
	chmod 666 $_hourlyUsageDB
	$send2log "  >>> Hourly usage file not found... creating new file: $_hourlyUsageDB" 2
	doliveUpdates
	local upsec=$(cat /proc/uptime | cut -d' ' -f1)
	local ds=$(date +"%Y-%m-%d %H:%M:%S")

	local hc="var hourly_created=\"$ds\""
	_pndData=$(getStartPND 'start' "$upsec")
	local hourlyHeader=$(getHourlyHeader "$upsec" "$ds")
	_hourlyData=''
	local nht="$_hourlyCreated
$hourlyHeader

$_pndData"
	save2File "$nht" "$_hourlyUsageDB"
	[ "$_symlink2data" -eq "0" ] && copyfiles "$_hourlyUsageDB" "$_hourlyUsageWWW"

}
getHourlyHeader(){
	$send2log "=== getHourlyHeader ===" -1

	local meminfo=$(cat /proc/meminfo)
	local freeMem=$(getMI "$meminfo" "MemFree")
	local bufferMem=$(getMI "$meminfo" "Buffers")
	local cacheMem=$(getMI "$meminfo" "Cached")
	local availMem=$(($freeMem+$bufferMem+$cacheMem))
	local disk_utilization=$(df "${d_baseDir}/" | grep -o "[0-9]\{1,\}%")
	$send2log "  getHourlyHeader:_totMem-->$_totMem" -1

	echo "
var hourly_updated=\"$2\"
var users_updated=\"$_usersLastMod\"
var disk_utilization=\"$disk_utilization\"
var serverUptime=\"$1\"
var freeMem=\"$freeMem\",availMem=\"$availMem\",totMem=\"$_totMem\"
serverloads(\"$sl_min\",\"$sl_min_ts\",\"$sl_max\",\"$sl_max_ts\")

"
}
getStartPND(){
	$send2log "=== getStartPND ===" -1
	local thr="$1"
	$send2log "  *** setting start in pnd - $_br_d / $_br_u" 1
	if [ -z "$_br_d" ] || [ -z "$_br_u" ] ; then
		local tstr=$(getPND "$thr" "$upsec")
		_br_u=$(getCV "$tstr" 'up')
		_br_d=$(getCV "$tstr" 'down')
	fi
	$send2log "  *** getStartPND: _br_d: $_br_d  _br_u: $_br_u" -1

	local ip4=$(getForwardData 'iptables' $YAMON_IP4)
	local ip6=''
	[ "$_includeIPv6" -eq "1" ] && ip6=$(getForwardData 'ip6tables' $YAMON_IP6)

	local result="pnd({\"hour\":\"$thr\",\"uptime\":$2,\"down\":$_br_d,\"up\":$_br_u,\"lost\":$_totalLostBytes,\"hr-loads\":\"$hr_min1,$hr_min5,$hr_max5,$hr_max1\"$ip4$ip6})"
	echo "$result"
}
getPND(){
	$send2log "=== getPND ===" -1
	local thr="$1"
	local br0=$(cat "/proc/net/dev" | grep -i "$_lan_iface" | tr -s ': ' ' ')
	$send2log "  *** PND: br0: [$br0]" -1
	local br_d=$(echo $br0 | cut -d' ' -f10)
	local br_u=$(echo $br0 | cut -d' ' -f2)
	[ "$br_d" == '0' ] && br_d=$(echo $br0 | cut -d' ' -f11)
	[ "$br_u" == '0' ] && br_u=$(echo $br0 | cut -d' ' -f3)
	[ -z "$br_d" ] && br_d=0
	[ -z "$br_u" ] && br_u=0
	$send2log "  *** PND: br_d: $br_d  br_u: $br_u" -1

	local ip4=$(getForwardData 'iptables' $YAMON_IP4)
	local ip6=''
	[ "$_includeIPv6" -eq "1" ] && ip6=$(getForwardData 'ip6tables' $YAMON_IP6)

	local result="pnd({\"hour\":\"$thr\",\"uptime\":$2,\"down\":$br_d,\"up\":$br_u,\"lost\":$_totalLostBytes,\"hr-loads\":\"$hr_min1,$hr_min5,$hr_max5,$hr_max1\"$ip4$ip6})"
	echo "$result"
}
setUsers(){
	$send2log "=== setUsers ===" -1
	_usersFile="$_dataPath$_usersFileName"
	[ "$_symlink2data" -eq "0" ] && _usersFileWWW="$_wwwPath$_wwwData$_usersFileName"

	[ ! -f "$_usersFile" ] && createUsersFile
	_currentUsers=$(cat "$_usersFile" | sed -e "s~(dup) (dup)~(dup)~Ig")
	[ "$_includeBridge" -eq "1" ] && checkBridge

	if [ ! -z "$_lan_ipaddr" ] ; then
		local lipe=$(echo "$_currentUsers" | grep "\b$_lan_ipaddr\b")
		[ -z "$lipe" ] && add2UsersJS $_lan_hwaddr $_lan_ipaddr 0 "Hardware" "LAN MAC"

	fi

	if [ ! -z "$_wan_ipaddr" ] ; then
		lipe=$(echo "$_currentUsers" | grep "\b$_wan_ipaddr\b")
		[ -z "$lipe" ] && [ "$_wan_hwaddr" != "$_lan_hwaddr" ] && add2UsersJS $_wan_hwaddr $_wan_ipaddr 0 "Hardware" "WAN MAC"
	fi

	lipe=$(echo "$_currentUsers" | grep "\b$_generic_ipv4\b")
	[ -z "$lipe" ] && add2UsersJS $_generic_mac $_generic_ipv4 0 "Unknown" "No Matching MAC"
	if [ "$_includeIPv6" -eq "1" ] ; then
		lipe=$(echo "$_currentUsers" | grep "[\b\"]$_generic_ipv6\b")
		[ -z "$lipe" ] && updateinUsersJS $_generic_mac $_generic_ipv6 1 "Unknown" "No Matching MAC"
	fi

	$send2log "	  started-->$started  _includeIPv6-->$_includeIPv6  " -1
	[ "$started" -eq "0" ] && checkUsers4IP
	$send2log "  _currentUsers -->
$_currentUsers" -1
}
checkUsers4IP()
{
	$send2log "=== checkUsers4IP ===" -1
	local ccd=$(echo "$_currentUsers" | grep 'users_created' | cut -d= -f2)
	ccd=${ccd//\"/}
	[ -z "$ccd" ] && ccd=$(date +"%Y-%m-%d %H:%M:%S")
	IFS=$'\n'
	local ncu="var users_created=\"$ccd\"
	"
	local nline=''
	local cdl=$(echo "$_currentUsers" | grep 'ud_a')
	local dups=''
	for device in $(echo "$cdl")
	do
		local hasIP=$(echo $device | grep '\"ip\"')
		local hasIP6=$(echo $device | grep '\"ip6\"')
		if [ -z "$hasIP" ] && [ -z "$hasIP6" ] ; then
			nline=$(echo $device | sed -e "s~\"owner\"~\"ip\":\"\",\"ip6\":\"\",\"owner\"~Ig" )
		elif [ -z "$hasIP6" ] ; then
			nline=$(echo $device | sed -e "s~\"owner\"~\"ip6\":\"\",\"owner\"~Ig" )
		elif [ -z "$hasIP" ] ; then
			nline=$(echo $device | sed -e "s~\"ip6\"~\"ip\":\"\",\"ip6\"~Ig" )
		else
			nline="$device"
		fi
		local hasLS=$(echo $device | grep '\"last-seen\"')
		if [ -z "$hasLS" ] ; then
			nline=$(echo $device | sed -e "s~})~,\"last-seen\":\"\"})~Ig" )
		fi
		ncu="$ncu
$nline"

		local mac=$(getField "$device" 'mac')
		local nm=$(echo "$cdl" | grep -ic "$mac" )
		[ $nm -eq 1 ] && continue
		local de=$(echo "$dups" | grep -i "$mac")
		if [ -z "$de" ] && [ -z "$dups" ] ; then
			dups="	$mac"
		elif [ -z "$de" ] ; then
			dups="$dups
	$mac"
		fi
	done
	[ ! -z "$dups" ] && [ "$_allowMultipleIPsperMAC" -eq "0" ] && $send2log "There are duplicated mac addresses in $_usersFile:
$dups" 99
	_currentUsers="$ncu"
	save2File "$_currentUsers" "$_usersFile"
}
createUsersFile()
{
	$send2log "=== createUsersFile ===" -1
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local users=''
	$send2log "  >>> Creating empty users file: $_usersFile" -1
	touch $_usersFile
	chmod 666 $_usersFile
	users="var users_created=\"$ds\""
}
setFirmware()
{
	$send2log "=== setFirmware ===" -1
	
	
	if [ "$_use_nf_conntrack" -ne "1" ] ; then
		_conntrack="/proc/net/ip_conntrack"
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); if($1 == "tcp"){ printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$1,$5,$7,$6,$8;} else { printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$1,$4,$6,$5,$7;} } END { print "[ null ] ]"}'
	
	else
		_conntrack="/proc/net/nf_conntrack"
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); if($3 == "tcp"){ printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$7,$9,$8,$10;} else { printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$6,$8,$7,$9;} } END { print "[ null ] ]"}'
	
	fi
	
	_lan_iface='br0'
	if [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] || [ "$_firmware" -eq "6" ] ; then #OpenWRT & variants
		_lan_iface="br-lan"
	fi
	_lan_ipaddr=$(ifconfig $_lan_iface | grep 'inet addr:' | tr -s ' ' | cut -d' ' -f3 | cut -d: -f2)
	_lan_hwaddr=$(ifconfig $_lan_iface | grep 'HWaddr' | tr -s ' ' | cut -d' ' -f5 | tr '[A-Z]' '[a-z]')
	
	_wan_ipaddr=$(ifconfig 'eth0' | grep 'inet addr:' | tr -s ' ' | cut -d' ' -f3 | cut -d: -f2)
	_wan_hwaddr=$(ifconfig 'eth0' | grep 'HWaddr' | tr -s ' ' | cut -d' ' -f5 | tr '[A-Z]' '[a-z]')
	if [ "$_has_nvram" -eq 1 ] ; then
		[ -z "$_wan_ipaddr" ] && wan_ipaddr=$(nvram get wan_ipaddr)
		[ -z "$wan_hwaddr" ] && _wan_hwaddr=$(nvram get wan_hwaddr)
	fi
	[ "$_includeIPv6" -eq "1" ] && _lan_ip6addr=$(ifconfig $_lan_iface | grep 'inet6 addr:' | grep -v fe80 | tr -s ' ' | cut -d' ' -f4)

}
checkBridge()
{
	$send2log "=== checkBridge ===" -1
	local foundBridge=$(echo "$_currentUsers" | grep -i "$_bridgeMAC")
	[ -z "$foundBridge" ] && add2UsersJS $_bridgeMAC $_bridgeIP 0 "Hardware" "Bridge MAC"
}
setConfigJS()
{
	$send2log "=== setConfigJS ===" -1
	if [ "$_symlink2data" -eq "0" ] ; then
		local configjs="$_wwwPath$_wwwJS$_configWWW"
	else
		local configjs="${d_baseDir}/$_setupWebDir$_wwwJS$_configWWW"
	fi
	local processors=$(grep -i processor /proc/cpuinfo -c)

	#Check for directories
	if [ ! -f "$configjs" ] ; then
		$send2log "  >>> $_configWWW not found... creating new file: $configjs" 2
		touch $configjs
		chmod 666 $configjs
	fi
	local configtxt="var _ispBillingDay=$_ispBillingDay
var _wwwData='$_wwwData'
var _scriptVersion='$_version'
var _file_version='$_file_version'
var _usersFileName='$_usersFileName'
var _usageFileName='$_usageFileName'
var _hourlyFileName='$_hourlyFileName'
var _processors='$processors'
var _doLiveUpdates='$_doLiveUpdates'
var _updatefreq='$_updatefreq'"
	[ "$_includeIPv6" -eq "1" ] && configtxt="$configtxt
var _includeIPv6='1'"
	[ "$_doLiveUpdates" -eq "1" ] && configtxt="$configtxt
var _liveFileName='./$_wwwJS$_liveFileName'
var _doCurrConnections='$_doCurrConnections'"
configtxt="$configtxt
var _unlimited_usage='$_unlimited_usage'
var _doLocalFiles='$_doLocalFiles'
var _organizeData='$_organizeData'"
	[ "$_unlimited_usage" -eq "1" ] && configtxt="$configtxt
var _unlimited_start='$_unlimited_start'
var _unlimited_end='$_unlimited_end'"
if [ ! "$_settings_pswd" == "" ] ; then
	local _md5_pswd=$(echo -n "$_settings_pswd" | md5sum | awk '{print $1}')
	configtxt="$configtxt
var _settings_pswd='$_md5_pswd'"
	fi
	[ ! "$_dbkey" == "" ] && configtxt="$configtxt
var _dbkey='$_dbkey'"

	save2File "$configtxt" "$configjs"

	$send2log "  >>> configjs --> $configjs" -1
	$send2log "  >>> configtxt --> $configtxt" -1
}
shutDown(){
	#one last backup before shutting down
	$send2log "=== shutDown ===" 1

	updateHourly
	[ "$_symlink2data" -eq "0" ] && [ "$_dowwwBU" -eq 1 ] && doFinalBU

	#eval iptables $_tMangleOption -F "$YAMON_IP4"
    #eval iptables $_tMangleOption -A "$YAMON_IP4" -j "RETURN" -s $_generic_ipv4 -d $_generic_ipv4

	#if [ "$_includeIPv6" -eq "1" ] ; then
        #eval ip6tables $_tMangleOption -F "$YAMON_IP6"
        #eval ip6tables $_tMangleOption -A "$YAMON_IP6" -j "RETURN" -s $_generic_ipv6 -d $_generic_ipv6
    #fi
	$send2log "
	=====================================
	\`yamon.sh\` has been stopped.
	-------------------------------------" 2
	exit 0

}

changeDates()
{
	$send2log "	 >>> date change: $_pDay --> $_cDay " 1
	updateHourly $_p_hr
	updateHourly2Monthly $_cYear $_cMonth $_pDay &
	local avrt='n/a'
	[ "$_dailyiterations" -gt "0" ] && avrt=$(echo "$_totalDailyRunTime $_dailyiterations" | awk '{printf "%.3f \n", $1/$2}')
	$send2log "	 >>> Daily stats:  day-> $_pDay  #iterations--> $_dailyiterations   total runtime--> $_totalDailyRunTime   Ave--> $avrt	min-> $_daily_rt_min   max--> $_daily_rt_max" 1
	_hriterations=0
	_dailyiterations=0
	_totalhrRunTime=0
	_totalDailyRunTime=0
	_hr_rt_max=''
	_hr_rt_min=''
	_daily_rt_max=''
	_daily_rt_min=''
	local yEntry=$(iptables -L YAMON33v4Entry -vnxZ | tr -s '-' ' ' | grep "^ [1-9]" | cut -d' ' -f2,3,8,9,10 | sort -k3)
	local yLocal=$(iptables -L YAMON33v4Local -vnxZ | tr -s '-' ' ' | grep "^ [1-9]" | cut -d' ' -f2,3,8,9,10 | sort -k3)
	local yall=$(iptables -L yall -vnxZ | tr -s '-' ' ' | grep "^ [1-9]" | cut -d' ' -f2,3,8,9,10 | sort -k3)
	$send2log "	 >>> YAMON33v4Entry:
$yEntry" 0
	$send2log "	 >>> YAMON33v4Local:
$yLocal" 0
	$send2log "	 >>> yall:
$yall" 0
	[ "$_doDailyBU" -eq "1" ] && dailyBU "$_cYear-$_cMonth-$_pDay" &
	sl_max=''
	sl_min=''
	hr_max5=''
	hr_min5=''
	hr_max1=''
	hr_min1=''
	sl_max_ts=''
	sl_min_ts=''
	ndAMS=0
	_totalLostBytes=0
	_pndData=""

	_cMonth=$(date +%m)
	_cYear=$(date +%Y)
	_ds="$_cYear-$_cMonth-$_cDay"
	if [ "$_unlimited_usage" -eq "1" ] ; then
		_ul_start=$(date -d "$_unlimited_start" +%s);
		_ul_end=$(date -d "$_unlimited_end" +%s);
		[ "$_ul_end" -lt "$_ul_start" ] && _ul_start=$((_ul_start - 86400))
		$send2log "	  _unlimited_usage-->$_unlimited_usage ($_unlimited_start->$_unlimited_end / $_ul_start->$_ul_end)" 1
	fi

	setLogFile
	updateServerStats
	setDataDirectories
	_pDay="$_cDay"
}
checkIPs()
{
	$send2log "=== checkIPs ===" 0
	_changesInUsersJS=0
	checkIPv4 $YAMON_IP4
	[ "$_includeIPv6" -eq "1" ] && checkIPv6
	if [ "$_changesInUsersJS" -gt "0" ] ; then
		$send2log "	>>> $_changesInUsersJS changes in users.js" 1
		save2File "$_currentUsers" "$_usersFile"
	fi
}

checkIPv4()
{
	$send2log "=== checkIPv4 ===" -1
	local ipl="$(eval "$_getIP4List")"
	local ipv4=$(getMACIPList "iptables" "$YAMON_IP4" "$ipl")
	$send2log "	>>> ipv4 ->
$ipv4" -1
	IFS=$'\n'
	for line in $(echo "$ipv4")
	do
		[ -z $line ] && continue
		local mac=$(echo "$line" | cut -d' ' -f1)
		local ip=$(echo "$line" | cut -d' ' -f2)
		CheckUsersJS $mac $ip 0
	done
	unset IFS
}
checkIPv6()
{
	$send2log "=== checkIPv6 ===" -1
	local ipl="$(eval "$_getIP6List")"
	local ipv6=$(getMACIPList "ip6tables" "$YAMON_IP6" "$ipl")
	$send2log "	>>> ipv6 ->
$ipv6" -1
	IFS=$'\n'
	for line in $(echo "$ipv6")
	do
		[ -z $line ] && continue
		local mac=$(echo "$line" | cut -d' ' -f1)
		local ip=$(echo "$line" | cut -d' ' -f2)
		CheckUsersJS $mac $ip 1
	done
	unset IFS
}
CheckUsersJS()
{
	$send2log "  === CheckUsersJS ===" -1
	$send2log "	  Arguments: $1 $2 $3" -1

	local mac=$1
	local ip=$2
	local is_ipv6=$3
	local tip=${ip//\./\\.}
	if [ "$_includeBridge" -eq "1" ] && [ "$mac" == "$_bridgeMAC" ] ; then
			local ipcount=$(echo "$_currentUsers" | grep -ic "[\b\",]$tip\b")
		if [ "$ipcount" -eq 0 ] ; then
			$send2log "	--- matched bridge mac but no matching entry for $ip.  Data will be tallied under bridge mac" 1
		elif [ "$ipcount" -eq 1 ] ; then
			mac=$(echo "$_currentUsers" | grep -i "[\b\",]$tip\b" | grep -io '\([a-z0-9]\{2\}\:\)\{5,\}[a-z0-9]\{2\}')
			$send2log "	--- matched bridge mac and found a unique entry for associated IP: $ip.  Changing MAC from $_bridgeMAC (bridge) to $mac (device)" 1
		else
			$send2log "	--- matched bridge mac but found $ipcount matching entries for $ip.  Data will be tallied under bridge mac" 1
		fi
	fi

	local cu_no_dup=$(echo "$_currentUsers" | grep -v "$ip (dup)")
	local ie=$(echo "$cu_no_dup" | grep -ic "[\b\",]$tip\b")
	
	local mie=$(echo "$cu_no_dup" | grep -i "$mac" | grep -ic "[\b\",]$tip\b")
	if [ "$mie" -eq "1" ] ; then
		[ "$ie" -gt "1" ] && clearDupIPs $ip $ie
		$send2log "	>>> $mac & $ip exist in users.js" -1
		return
	fi
	local mied=$(echo "$_currentUsers" | grep -i "$mac" | grep -ic "[\b\",]$tip (dup)")
	if [ "$mie" -eq "1" ] ; then
		[ "$ie" -gt "1" ] && clearDupIPs $ip $ie
		$send2log "	>>> $mac & $ip removing (dup)" -1
		updateinUsersJS "$mac" "$ip" "$is_ipv6"
		return
	fi
	local me=$(echo "$_currentUsers" | grep -ic "$mac")
	$send2log "  mac: $mac	ip: $ip	mie-->$mie	me-->$me	ie-->$ie" 1
	[ "$ie" -ge "1" ] && clearDupIPs $ip $ie
	if [ "$me" -eq "0" ] ; then
		$send2log "	>>> $mac does not exist in users.js... adding a new entry" 1
		$send2log "	  _currentUsers before:
$_currentUsers" -1
		add2UsersJS $mac $ip $is_ipv6
	elif [ "$_allowMultipleIPsperMAC" -eq "0" ] ; then
		if [ "$me" -eq "1" ] ; then
			$send2log "	>>> $mac exists in users.js... updating existing unique entry" 1
			updateinUsersJS "$mac" "$ip" "$is_ipv6"
		else
			$send2log "There are $me entries for $mac in users.js but it should be unique" 2
		fi
	elif [ "$_allowMultipleIPsperMAC" -eq "1" ]; then
		$send2log "	>>> multiple ips are allowed for $mac in users.js... adding a new entry" 1
		add2UsersJS $mac $ip $is_ipv6
	fi
}
clearDupIPs()
{
	$send2log "  === clearDupIPs ===" -1
	local ip=$1
	local ie=$2
	$send2log "	>>> $ie other instance(s) of $ip exist in users.js... removing duplicate(s)" 1
	local tip=${ip//\./\\.}
	_currentUsers=$(echo "$_currentUsers" | sed -e "s~\b$tip\b~$ip (dup)~Ig" | sed -e "s~(dup) (dup)~(dup)~Ig")
}
updateinUsersJS()
{
	$send2log "=== updateinUsersJS ===" -1
	$send2log "  arguments: $1 $2 $3" -1

	local mac=$1
	local new_ip=$2
	local is_ipv6=$3

	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local line=$(echo "$_currentUsers" | grep -i "$mac" )
	$send2log "	  line1-->$line" -1

	if [ -z "$line" ] ; then
		$send2log "updateinUsersJS: Could not find $mac in _currentUsers... this should not be possible?!? " 2
		return
	fi
	local old_ip=''
	local ips='ip'
	[ "$is_ipv6" -eq 1 ] && ips='ip6'

	old_ip=$(getField "$line" "$ips")
	line=$(replace "$line" "$ips" "$new_ip")
	line=$(replace "$line" "updated" "$ds")
	_currentUsers=$(echo "$_currentUsers" | sed -e "s~.\{0,\}\"$mac\".\{0,\}~$line~Ig")
	_changesInUsersJS=$(($_changesInUsersJS + 1))
	$send2log "  >>> Device $mac & $old_ip ($is_ipv6) was updated to $mac & $new_ip
$line" 1
}
add2UsersJS()
{
	$send2log "=== add2UsersJS ===" -1
	local mac=$1
	local ip=$2
	local is_ipv6=$3
	local oname=''
	local dname=''
	[ ! -z "$4" ] && oname="$4"
	[ ! -z "$5" ] && dname="$5"
	local kvs=''
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	if [ -z "$oname" ] || [ -z "$dname" ] ; then
		local deviceName=$(getDeviceName $mac)
		$send2log "		deviceName-->$deviceName" -1
		if [ -z "$_do_separator" ] ; then
			local oname="$_defaultOwner"
			local dname="$deviceName"
		else
			local oname=${deviceName%%"$_do_separator"*}
			local dname=${deviceName#*"$_do_separator"}
		fi
	fi
	
	#add count of new devices
	local inc_count=$(echo "$_currentUsers" | grep -c "$_defaultDeviceName")
	inc_count=$(printf %02d $(($inc_count+1)) )

	[ -z "$dname" ] || [ "$dname" == '*' ] && dname="$_defaultDeviceName-$inc_count"
	[ -z "$oname" ] || [ "$oname" == '*' ] && oname="$_defaultOwner"

	if [ "$is_ipv6" -eq '0' ] ; then
		local ip_str="\"ip\":\"$ip\","
		local ip6_str=""
		[ "$_includeIPv6" -eq "1" ] && ip6_str="\"ip6\":\"\","
	else
		local ip_str="\"ip\":\"\","
		local ip6_str="\"ip6\":\"$ip\","
	fi
	#to do... fix multiple IPs/mac
	if [ "$_allowMultipleIPsperMAC" -eq "1" ] ; then
#TODO where does users get assigned?
		local kv=$(echo "$users" | grep -ic "$mac")||0
		[ "$kv" -gt "0" ] && kvs="\"key\":$kv,"
	fi
	local newuser="ud_a({\"mac\":\"$mac\",$ip_str$ip6_str$kvs\"owner\":\"$oname\",\"name\":\"$dname\",\"colour\":\"\",\"added\":\"$ds\",\"updated\":\"$ds\",\"last-seen\":\"$ds\"})"
	$send2log "New device $dname (group $oname) was added to the network: $mac & $ip ($is_ipv6)" 99
	$send2log "		newuser-->$newuser" -1
	_changesInUsersJS=$(($_changesInUsersJS + 1))
	_currentUsers="$_currentUsers
$newuser"
	$send2log "	  _currentUsers-->$_currentUsers" -1
}
getDeviceName()
{
	$send2log "=== getDeviceName ===" -1
	local mac=$1

	if [ "$_firmware" -eq "0" ] ; then
		local nvr=$(nvram show 2>&1 | grep -i "static_leases=")
		local result=$(echo "$nvr" | grep -io "$mac[^=]*=.\{1,\}=.\{1,\}=" | cut -d= -f2)
	elif [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] || [ "$_firmware" -eq "6" ] ; then
		# thanks to Robert Micsutka for providing this code & easywinclan for suggesting & testing improvements!
		local ucihostid=$(uci show dhcp | grep -i $mac | cut -d. -f2)
		[ -n "$ucihostid" ] && local result=$(uci get dhcp.$ucihostid.name)
	elif [ "$_firmware" -eq "2" ] || [ "$_firmware" -eq "5" ] ; then
		#thanks to Chris Dougherty for providing this code
		local nvr=$(nvram show 2>&1 | grep -i "dhcp_staticlist=")
		local nvrt=$nvr
		local nvrfix=''
		while [ "$nvrt" ] ;do
			iter=${nvrt%%<*}
			nvrfix="$nvrfix$iter="
			[ "$nvrt" = "$iter" ] && \
				nvrt='' || \
				nvrt="${nvrt#*<}"
		done
		local nvr=${nvrfix//>/=}
			#local result=$(echo "$nvr" | grep -io "$mac=.\{1,\}=.\{1,\}=" | cut -d= -f3)
		local result=$(echo "$nvr" | grep -io "$mac[^=]*=.\{1,\}=.\{1,\}=" | cut -d= -f3)
	fi
	[ -z "$result" ] && [ -f "$_dnsmasq_conf" ] && result=$(echo "$(cat $_dnsmasq_conf | grep -i "dhcp-host=")" | grep -i "$mac" | cut -d, -f2)
	[ -z "$result" ] && [ -f "$_dnsmasq_leases" ] && result=$(echo "$(cat $_dnsmasq_leases)" | grep -i "$mac" | tr '\n' ' / ' | cut -d' ' -f4)
	echo "$result"
}
checkTimes()
{
	$send2log "=== checkTimes ===" 0
	_cDay=$(date +"%d")
	[ "$_cDay" != "$_pDay" ] && changeDates

	local hr=$(date +"%H")
	[ "$hr" -ne "$_p_hr" ] && changeHour "$hr"

	if [ "$_unlimited_usage" -eq "0" ] ; then
	   _inUnlimited=0
	   return
	fi

	local currTime=$(date +"%s")
	_inUnlimited=$((currTime >= _ul_start && currTime <= _ul_end))
	$send2log "  _inUnlimited-->$_inUnlimited	_p_inUnlimited-->$_p_inUnlimited   currTime-->$currTime   _ul_start-->$_ul_start   _ul_end-->$_ul_end" -1

	[ "$_inUnlimited" -eq "1" ] && [ "$_p_inUnlimited" -eq "0" ] && $send2log "	--- starting unlimited usage interval: $_unlimited_start" 1
	[ "$_inUnlimited" -eq "0" ] && [ "$_p_inUnlimited" -eq "1" ] && $send2log "	--- ending unlimited usage interval: $_unlimited_end" 1
	_p_inUnlimited=$_inUnlimited

}
changeHour()
{
	local hr="$1"
	updateHourly $_p_hr
	$send2log "	 >>> hour change: $_p_hr --> $hr " 0
	local avrt='n/a'
	[ "$_hriterations" -gt "0" ] && avrt=$(echo "$_totalhrRunTime $_hriterations" | awk '{printf "%.3f \n", $1/$2}')
	$send2log "	 >>> Hourly stats:  hr-> $_p_hr  #iterations--> $_hriterations   total runtime--> $_totalhrRunTime   Ave--> $avrt	min-> $_hr_rt_min   max--> $_hr_rt_max" 1
	_dailyiterations=$(($_dailyiterations+$_hriterations))
	_totalDailyRunTime=$(($_totalDailyRunTime+$_totalhrRunTime))
	_daily_rt_max=$(maxI $_daily_rt_max $_hr_rt_max )
	_daily_rt_min=$(minI $_daily_rt_min $_hr_rt_min )
	$send2log "_thisHrpnd ($_p_hr): $_thisHrpnd" 1

	_hr_rt_max=''
	_hr_rt_min=''
	_hriterations=0
	_totalhrRunTime=0
	hr_max5=''
	hr_min5=''
	hr_max1=''
	hr_min1=''
	_totalLostBytes=0

	if [ ! -z "$end" ] ; then
		$send2log "_thisHrdata: ($_p_hr)
$_thisHrdata" 1
		_hourlyData="$_hourlyData
$_thisHrdata"
		$send2log "_thisHrpnd: ($_p_hr)
$_thisHrpnd" 1
		_pndData="$_pndData
$_thisHrpnd"
	fi
	_thisHrdata=''
	_thisHrpnd=''
	_p_hr=$hr
}
updateServerStats()
{
	$send2log "=== updateServerStats === " 0
	local cTime=$(date +"%T")
	if [ -z "$sl_max" ] || [ "$sl_max" \< "$load5" ] ; then
		sl_max=$load5
		sl_max_ts="$cTime"
	fi
	if [ -z "$sl_min" ] || [ "$load5" \< "$sl_min" ] ; then
		sl_min="$load5"
		sl_min_ts="$cTime"
	fi
	hr_max1=$(maxF $hr_max1 $load1 )
	hr_max5=$(maxF $hr_max5 $load5 )
	hr_min1=$(minF $hr_min1 $load1 )
	hr_min5=$(minF $hr_min5 $load5 )
}

doliveUpdates()
{
	$send2log "=== doliveUpdates === ($_liveFilePath)" 0
	local loadavg=$(cat /proc/loadavg)
	$send2log "  >>> loadavg: $loadavg" -1
	load1=$(echo "$loadavg" | cut -f1 -d" ")
	load5=$(echo "$loadavg" | cut -f2 -d" ")
	local load15=$(echo "$loadavg" | cut -f3 -d" ")
	local cTime=$(date +"%T")
	echo "var last_update='$_cYear/$_cMonth/$_cDay $cTime'
serverload($load1,$load5,$load15)" > $_liveFilePath

	if [ "$_doCurrConnections" -eq "1" ] ; then
		$send2log "	>>> curr_connections" -1
		local ddd=$(awk "$_conntrack_awk" "$_conntrack")
		echo "$ddd"  >> $_liveFilePath
		$send2log "	curr_connections >>>
$ddd" 0
	fi

	$send2log "	>>> _liveusage: $_liveusage" -1
	echo "$_liveusage" >> $_liveFilePath
	_liveusage=''
 	[ "$_doArchiveLiveUpdates" -eq "1" ] && cat "$_liveFilePath" >> $_liveArchiveFilePath
}
checkConfig()
{
	$send2log "=== checkConfig ===" 0
	local _configMd5=$(md5sum $_configFile | cut -f1 -d" ")
	[ "$started" -eq "1" ] && $send2log "  >>> _configMd5 --> $_configMd5   _savedconfigMd5 --> $_savedconfigMd5  " -1

	if [ "$_configMd5" == "$_savedconfigMd5" ] ; then
		$send2log '  >>> _configMd5 == _savedconfigMd5' -1
		return
	fi
	_savedconfigMd5="$_configMd5"
	$send2log "--- config.file has changed!  Resetting setInitValues ---" 2
	setConfigJS
	[ "$_enable_ftp" -eq 1 ] && send2FTP "$_configFile"
	updateHourly
	setInitValues
}

update()
{
	lostBytes()
	{
		local nb=$2
		[ -z "$nb" ] && nb=0
		$send2log "	  +++ lostBytes-->$_totalLostBytes ($nb)" -1
		_totalLostBytes=$(digitAdd "$_totalLostBytes" "$nb")
		$send2log "$1 (_totalLostBytes=$_totalLostBytes / $nb)" 2
	}
	
	$send2log "	  +++ update" -1
	$send2log "	 update arguments: $1 $2 $3 $4" -1

	local ds=$(date +"%Y-%m-%d %H:%M:%S")

	local ip="${1%/128}"
	local tip=${ip//\./\\.}
	local do="$2"
	local up="$3"
	local hr="$4"
	local bytes=$(digitAdd "$do" "$up")
	local cu_no_dup=$(echo "$_currentUsers" | grep -vi "$tip (dup)")
	local cuc=$(echo "$cu_no_dup" | grep -ic "[\b\",]$tip\b")
	if [ "$cuc" -eq 0 ] ; then
		lostBytes "	  !!! No matching entry in _currentUsers for $mac / $ip ($tip)?!? - adding $bytes to unknown mac " $bytes
		update "$_generic_ipv4" "$do" "$up" "$hr"
		return
	elif [ "$cuc" -gt 1 ] ; then
		lostBytes "	  !!! $cuc matching entries in _currentUsers for $ip ($tip)?!? returning - adding $bytes to unknown mac " $bytes
		update "$_generic_ipv4" "$do" "$up" "$hr"
		return
	fi
	local pdo=0
	local pup=0

	local new_do=$do
	local new_up=$up
	[ -z "$new_do" ] && new_do=0
	[ -z "$new_up" ] && new_up=0
	local cu=$(echo "$cu_no_dup" | grep -i "[\b\",]$tip\b")
	local mac=$(getField "$cu" 'mac')
	if [ -z "$mac" ] ; then
		$send2log "		  cu-->$cu" -1
		lostBytes "	  !!! No matching MAC in _currentUsers for $ip?!? - adding $bytes to unknown mac " $bytes
		update "$_generic_ipv4" "$new_do" "$new_up" "$hr"
		return
	elif [ "$mac" == "00:00:00:00:00:00" ] || [ "$mac" == "failed" ] || [ "$mac" == "incomplete" ] ; then
		lostBytes "  >>> skipping null/invalid MAC address for $ip?!? - adding $bytes to unknown mac " $bytes
		update "$_generic_ipv4" "$new_do" "$new_up" "$hr"
		return
	elif [ "$_includeBridge" -eq "1" ] && [ "$mac" == "$_bridgeMAC" ] ; then
		local ipcount=$(echo "$cu_no_dup" | grep -v "\b$_bridgeMAC\b" | grep -ic "[\b\",]$tip\b")
		if [ "$ipcount" -eq 1 ] ;  then
			mac=$(echo "$cu_no_dup" | grep -i "[\b\",]$tip\b" | grep -io '\([a-z0-9]\{2\}\:\)\{5,\}[a-z0-9]\{2\}')
			$send2log "	--- matched bridge mac and found a unique entry for associated IP: $ip.  Changing MAC from $_bridgeMAC (bridge) to $mac (device)" 1
		else
			$send2log "	--- matched bridge mac but found $ipcount matching entries for $ip.  Data will be tallied under bridge mac" 1
		fi
	fi
	_liveusage="$_liveusage
curr_users({mac:'$mac',ip:'$ip',down:$new_do,up:$new_up})"
	[ "$_ignoreGateway" -eq "1" ] && [ "$mac" == "$_gatewayMAC" ] && return
	local cur_hd=$(echo "$_thisHrdata" | grep -i "\"$mac\".\{0,\}\"$hr\"")
	if [ -z "$cur_hd" ] ; then
		if [ "$_inUnlimited" -eq "0" ] ; then
			cur_hd="hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up"})"
		else
			cur_hd="hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up","\"ul_do\":$new_do,\"ul_up\":$new_up"})"
		fi
		$send2log "	  new ul row-->$cur_hd" 1
		_thisHrdata="$_thisHrdata
$cur_hd"
		return
	fi
	local hasUL=$(echo "$cur_hd" | grep "ul_do")
	pdo=$(getCV "$cur_hd" "down")
	pup=$(getCV "$cur_hd" "up")
	new_do=$(digitAdd "$do" "$pdo")
	new_up=$(digitAdd "$up" "$pup")
	if [ "$_inUnlimited" -eq "1" ] || [ ! -z "$hasUL" ] ; then
		local pul_do=$(getCV "$cur_hd" "ul_do")
		local pul_up=$(getCV "$cur_hd" "ul_up")
		local new_ul_do=$(digitAdd "$do" "$pul_do")
		local new_ul_up=$(digitAdd "$up" "$pul_up")
		cur_hd="hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up","\"ul_do\":$new_ul_do,\"ul_up\":$new_ul_up"})"
	else
		cur_hd="hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up"})"
	fi
	$send2log "		  updated $1 $2 $3 $4" -1
	$send2log "		  updated ul row-->$cur_hd" 0
	_thisHrdata=$(echo "$_thisHrdata" | sed -e "s~.\{0,\}\"$mac\".\{0,\}\"$hr\".\{0,\}~$cur_hd~Ig")
}
updateUsage()
{
	local cmd=$1
	local chain=$2
	$send2log "=== updateUsage ($cmd/$chain)=== " 0
	local hr=$(date +%H)
	_ud_list=''

    local iptablesData=$(eval $cmd $_tMangleOption -L "$chain" -vnxZ | tr -s '-' ' ' | grep "^ [1-9]" | cut -d' ' -f3,8,9)

	if [ -z "$iptablesData" ] ; then
		$send2log "	>>> $cmd returned no data... returning " 0
		return
	fi
	createUDList "$iptablesData"
	$send2log "iptablesData-->
$iptablesData" 0
	$send2log "_ud_list-->
$_ud_list" 0

	IFS=$'\n'
	for line in $(echo "$_ud_list")
	do
		$send2log "  >>> line-->$line" -1
		local ip=$(echo "$line" | cut -d',' -f1)
		local do=$(echo "$line" | cut -d',' -f2)
		local up=$(echo "$line" | cut -d',' -f3)
		update "$ip" "$do" "$up" "$hr"
	done
	unset IFS
}
updateHourly()
{
	local hr=$1
	[ -z "$hr" ] && hr=$(date +%H)
	$send2log "=== updateHourly === [$1 - $hr]" 1
	local upsec=$(cat /proc/uptime | cut -d' ' -f1)
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local hourlyHeader=$(getHourlyHeader "$upsec" "$ds")
	_thisHrpnd=$(getPND "$hr" "$upsec")
	_br_u=$(getCV "$_thisHrpnd" 'up')
	_br_d=$(getCV "$_thisHrpnd" 'down')
	$send2log "  _hourlyData--> $_hourlyData" -1
	$send2log "  _thisHrdata--> $_thisHrdata" 1
	$send2log "  _pndData-> $_pndData" -1
	$send2log "  _thisHrpnd-> $_thisHrpnd" 0
	local nht="$_hourlyCreated
$hourlyHeader

$_hourlyData
$_thisHrdata

$_pndData
$_thisHrpnd"
	save2File "$nht" "$_hourlyUsageDB"
}

runtimestats()
{
	local start=$1
	local end=$2

	$send2log "=== runtimestats === $_totalhrRunTime $_hriterations" 0
	local runtime=$(($end-$start))
	#local offset=$(($end%$_updatefreq))
	_totalhrRunTime=$(($_totalhrRunTime + $runtime))
	_hriterations=$(($_hriterations + 1))
	_hr_rt_max=$(maxI $_hr_rt_max $runtime )
	_hr_rt_min=$(minI $_hr_rt_min $runtime )
	pause=$(($_updatefreq-$runtime>0?$_updatefreq-$runtime:0))
	$send2log "  >>> #$_iteration - Execution time: $runtime seconds - pause: $pause seconds ($_hr_rt_min/$_hr_rt_max)" -1
	[ "$runtime" -gt "$_updatefreq" ] && $send2log "	 Execution time exceeded delay (${runtime}s)!" 2
}

# ==========================================================
#				  Main program
# ==========================================================

d_baseDir=$(cd "$(dirname "$0")" && pwd)
if [ ! -d "$d_baseDir/includes" ] || [ ! -f "$d_baseDir/includes/defaults.sh" ] ; then
	echo "
**************************** ERROR!!! ****************************
  You are missing the \`$d_baseDir/includes\` directory and/or
  files contained within that directory. Please re-download the
  latest version of YAMon and make sure that all of the necessary
  files and folders are copied to \`$d_baseDir\`!
******************************************************************
"
	exit 0
fi

source "${d_baseDir}/includes/versions.sh"
_configFile="$d_baseDir/config.file"
[ ! -f "$_configFile" ] && echo "$_s_noconfig" && exit 0
source "$_configFile"

source "${d_baseDir}/includes/defaults.sh"
source "$d_baseDir/includes/util$_version.sh"
source "$d_baseDir/strings/$_lang/strings.sh"

source "$d_baseDir/includes/hourly2monthly.sh"

#globals
_logfilename=''
_devicesDB=""
_monthlyDB=""
_hourlyDB=""
_liveDB=""
_hourlyFile=""
_hourlyFile=""
_hourlyData=""
_hourlyCreated=''
_currentConnectedUsers=""
_hData=""
_unlimited_usage=0
_unlimited_start=""
_unlimited_end=""
_inUnlimited=0
_p_inUnlimited=0
_savedconfigMd5=''
_usersLastMod=''
_totMem=''
_totalLostBytes=0
_changesInUsersJS=0
_hriterations=0
_liveusage=''
_ndAMS=0
_ndAMS_dailymax=24
_generic_ipv4="0.0.0.0/0"
_generic_ipv6="::/0"
_generic_mac="un:kn:ow:n0:0m:ac"
started=0
sl_max=""
sl_max_ts=""
sl_min=""
sl_min_ts=""
_iteration=0
_br_d=''
_br_u=''

installedversion='tbd'
installedtype='tbd'

installedfirmware=$(uname -o)
if [ "$_has_nvram" -eq 1 ] ; then
	installedversion=$(nvram get os_version)
	installedtype=$(nvram get dist_type)
fi

np=$(ps | grep -v grep | grep -c yamon)
if [ -d "$_lockDir" ] ; then
	echo "$(ps | grep -v grep | grep yamon$_version)"
	echo "$_s_running" && exit 0
fi
[ -x /usr/bin/clear ] && clear
echo "$_s_title"
_cYear=$(date +%Y)
[ "$_cYear" -lt "2015" ] && echo "$_s_cannotgettime" && exit 0

_cDay=$(date +%d)
_pDay="$_cDay"
_cMonth=$(date +%m)

_ds="$_cYear-$_cMonth-$_cDay"

sleep 5
setInitValues
$send2log "
**********************************************************
*  YAMon $_version was started
**********************************************************
" 2
timealign=$(($_updatefreq-$(date +%s)%$_updatefreq))
$send2log "  >>> Delaying ${timealign}s to align updates" 1
sleep  "$timealign";
_p_hr=$(date +%H)
$send2log "  >>> Starting main loop" 1

while [ 1 ]; do
	start=$(date +%s)

	checkTimes
	checkIPs
	updateUsage 'iptables' "$YAMON_IP4"
	[ "$_includeIPv6" -eq "1" ] && updateUsage 'ip6tables' "$YAMON_IP6"
	_iteration=$(($_iteration%$_publishInterval + 1))

	[ "$_doLiveUpdates" == "1" ] && doliveUpdates

	if [ $(($_iteration%$_publishInterval)) -eq 0 ] ; then
		updateServerStats
		checkConfig
		updateHourly
	fi

	end=$(date +%s)
	runtimestats $start $end
	n=1
	while [ 1 ]; do
		[ ! -d "$_lockDir" ] && shutDown
		[ "$n" -gt "$pause" ] && break
		n=$(($n+1))
		sleep 1
	done
done &