#!/bin/sh 

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-2016 Al Caughey
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
# 3.0.16 (2016-25-25): fixed some functions to returns zeroes rather than null
# 3.0.17 (2016-25-28): tweaks; Tomato updates as per Todd Saylor (in getDeviceName)
# 3.1.0 (2016-10-05): bumped to 3.1 because of breaking changes to yamon.html; FTP functionality; added checks for LAN & WAN IP addresses; fixed IP address regex
# 3.1.1 (2016-10-10): tweaks not caught in 3.1.0; added arp, added init script for OpenWrt (in setup.sh)
# 3.1.2 (2016-10-10): fixes in defaults.sh to set missing values in config.file to defaults
# 3.1.3 (2016-10-24): update config3.js if config.file changes; defensively check for $_dnsmasq_conf & proper values for FTPing
# 3.1.4 (2016-11-13): added YAMon rule to iptables INPUT & OUTPUT (in addition to FORWARD); fixed date issue in checkTimes
#                   : check for duplicate MAC addresses in users.js; reduced number of messages going to logs

# ==========================================================
#				  Functions
# ==========================================================

setInitValues(){
	_configFile="$d_baseDir/config.file"
	source "$_configFile"
	loadconfig
	source "$d_baseDir/strings/$_lang/strings.sh"
	_savedconfigMd5=$(md5sum $_configFile | cut -f1 -d" ")
	setLogFile
	setFirmware
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
		send2log "YAMon was started at $ts" 99
	fi
	[ "$_debugging" -eq "1" ] && set +x 
	local meminfo=$(cat /proc/meminfo)
	_totMem=$(getMI "$meminfo" "MemTotal")
	local ulmt=$(ls -e "$_usersFile" | tr -s ' ' ' ' )
	local lmy=$(echo "$ulmt" | cut -d' ' -f10)
	local lmm=$(echo "$ulmt" | cut -d' ' -f7)
	local lmd=$(echo "$ulmt" | cut -d' ' -f8)
	local lmt=$(echo "$ulmt" | cut -d' ' -f9)
	local months="Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"   
	local string="${months%$lmm*}"
	local lmmno=$(printf %02d $((${#string}/4 + 1)))
	local sortStr=''
	local cansort=$(echo "$(command -v sort)")
	[ ! -z "$canSort" ] && sortStr=" | sort -k2"

	local tip=$($_path2ip -4 neigh show)
	if [ -z "$tip" ] ; then
		_getIP4List="cat /proc/net/arp | grep '^[0-9]' | grep -v '00:00:00:00:00:00' | tr -s ' ' | cut -d' ' -f 1,4 | tr '[A-Z]' '[a-z]' $sortStr"
	else
		_getIP4List="$_path2ip -4 neigh | grep 'lladdr' | cut -d' ' -f 1,5 | tr '[A-Z]' '[a-z]' $sortStr"
	fi

	_usersLastMod="$lmy-$lmmno-$lmd $lmt"
	[ "$_debugging" -eq "1" ] && set -x 
	checkIPChain "iptables" "FORWARD" "$YAMON_IP4"
	checkIPChain "iptables" "INPUT" "$YAMON_IP4"
	checkIPChain "iptables" "OUTPUT" "$YAMON_IP4"
	if [ "$_includeIPv6" -eq "1" ] ; then
		_getIP6List="$_path2ip -6 neigh | grep 'lladdr' | cut -d' ' -f 1,5 | tr '[A-Z]' '[a-z]' $sortStr"
		checkIPChain 'ip6tables' 'FORWARD' $YAMON_IP6
		checkIPChain 'ip6tables' 'INPUT' $YAMON_IP6
		checkIPChain 'ip6tables' 'OUTPUT' $YAMON_IP6
	fi
	started=1
}
setLogFile()
{
	if [ "${_logDir:0:1}" == "/" ] ; then
		local lfpath=$_logDir
	else
		local lfpath="${_baseDir}$_logDir"
	fi
	[ ! -d "$lfpath" ] && mkdir -p "$lfpath"
	_logfilename="${lfpath}monitor-$_cYear-$_cMonth-$_cDay.log"
	[ ! -f "$_logfilename" ] && touch "$_logfilename" && send2log "YAMon :: version $_version	_loglevel: $_loglevel" 2
	send2log "=== setLogFile ===" -1
}
setWebDirectories()
{
	send2log "=== setWebDirectories ===" -1
	[ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] && [ ! -h "/www/user" ] && ln -s "/tmp/www" "/www/user"
	if [ "$_symlink2data" -eq "1" ] ; then
		if [ ! -d "$_wwwPath" ] ; then
			mkdir -p "$_wwwPath"
			chmod -R a+rX "$_wwwPath"
		fi
		local lcss=${_wwwCSS%/}
		local limages=${_wwwImages%/}
		local ldata=${_wwwData%/}
		[ ! -h "$_wwwPath$lcss" ] && ln -s "${_baseDir}$_setupWebDir$lcss" "$_wwwPath$lcss"
		[ ! -h "$_wwwPath$limages" ] && ln -s "${_baseDir}$_setupWebDir$limages" "$_wwwPath$limages"
		[ ! -h "$_wwwPath$ldata" ] && ln -s "$_dataPath" "$_wwwPath$ldata"
		[ ! -h "$_wwwPath$_setupWebIndex" ] && ln -s "${_baseDir}$_setupWebDir$_setupWebIndex" "$_wwwPath$_setupWebIndex"
	elif [ "$_symlink2data" -eq "0"  ] ; then
		copyfiles "${_baseDir}$_setupWebDir*" "$_wwwPath"
	fi
	[ ! -d "$_wwwPath$_wwwJS" ] && mkdir -p "$_wwwPath$_wwwJS"
}
setDataDirectories()
{
	send2log "=== setDataDirectories ===" -1
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
		_dataPath="${_baseDir}$_dataDir"
	fi
	send2log "  >>> _dataPath --> $_dataPath" 0
	if [ ! -d "$_dataPath" ] ; then
		send2log "  >>> Creating data directory" 0
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
		send2log "  >>> Adding data directory - $savePath " 0
		mkdir -p "$savePath"
		chmod -R 666 "$savePath"
	else
		send2log "  >>> data directory exists - $savePath " -1
	fi
	if [ "$_symlink2data" -eq "0" ] && [ ! -d "$wwwsavePath" ] ; then
		send2log "  >>> Adding web directory - $wwwsavePath " 0
		mkdir -p "$wwwsavePath"
		chmod -R 666 "$wwwsavePath"
	else
		send2log "  >>> web directory exists - $wwwsavePath " -1
	fi

	[ "$_symlink2data" -eq "0" ] &&  [ "$(ls -A $_dataPath)" ] && copyfiles "$_dataPath*" "$_wwwPath$_wwwData"

	_macUsageDB="$savePath$rYear-$rMonth-$rday-$_usageFileName"
	_macUsageWWW="$wwwsavePath$rYear-$rMonth-$rday-$_usageFileName"
	[ ! -f "$_macUsageDB" ] && createMonthlyFile
	[ "$_doLiveUpdates" -eq "1" ] && _liveFilePath="$_wwwPath$_wwwJS$_liveFileName"
	[ ! -d "$_wwwPath$_wwwJS" ] && mkdir -p "$_wwwPath$_wwwJS"
	if [ ! -f "$_liveFileName" ] ; then 
		touch $_liveFileName
		chmod 666 $_liveFileName
	fi
	_hourlyUsageDB="$savePath$_cYear-$_cMonth-$_cDay-$_hourlyFileName"
	_hourlyUsageWWW="$wwwsavePath$_cYear-$_cMonth-$_cDay-$_hourlyFileName"

	[ ! -f "$_hourlyUsageDB" ] && createHourlyFile
	[ "$_debugging" -eq "1" ] && set +x 
	local hd=$(cat "$_hourlyUsageDB")
	local hdhu=$(echo "$hd" | grep '^hu' )
	local hdpd=$(echo "$hd" | grep '^pnd' )
	_hourlyCreated=$(echo "$hd" | grep '^var hourly_created')
	local hr=$(date +"%H")
	_hourlyData=$(echo "$hdhu" | grep -v "\"hour\":\"$hr\"")
	_thisHrdata=$(echo "$hdhu" | grep "\"hour\":\"$hr\"")
	_pndData=$(echo "$hdpd" | grep -v "\"hour\":\"$hr\"")
	_thisHrpnd=$(echo "$hdpd" | grep "\"hour\":\"$hr\"")
	[ "$_debugging" -eq "1" ] && set -x 
	send2log "  _hourlyData--> $_hourlyData" -1
	send2log "  _thisHrdata ($hr)--> $_thisHrdata" 0
	send2log "  _pndData--> $_pndData" -1
	send2log "  _thisHrpnd ($hr)--> $_thisHrpnd" 0
}
createMonthlyFile()
{
	send2log "=== createMonthlyFile ===" -1
	send2log "  >>> Monthly usage file not found... creating new file: $_macUsageDB" 2
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	touch $_macUsageDB
	chmod 666 $_macUsageDB
	[ "$_debugging" -eq "1" ] && set +x 
	local nmf="var monthly_created=\"$ds\"
var monthly_updated=\"$ds\""
	save2File "$nmf" "$_macUsageDB"

	[ "$_debugging" -eq "1" ] && set -x 
	[ "$_symlink2data" -eq "0" ] && copyfiles "$_macUsageDB" "$_macUsageWWW"
	
}
createHourlyFile()
{
	send2log "=== createHourlyFile ===" -1
	touch $_hourlyUsageDB
	chmod 666 $_hourlyUsageDB
	send2log "  >>> Hourly usage file not found... creating new file: $_hourlyUsageDB" 2
	doliveUpdates
	[ "$_debugging" -eq "1" ] && set +x 
	local upsec=$(cat /proc/uptime | cut -d' ' -f1)
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	
	local hc="var hourly_created=\"$ds\""
	_pndData=$(getPND 'start' "$upsec")
	local hourlyHeader=$(getHourlyHeader "$upsec" "$ds")
	_hourlyData=''
	local nht="$_hourlyCreated
$hourlyHeader

$_pndData"
	save2File "$nht" "$_hourlyUsageDB"
	[ "$_debugging" -eq "1" ] && set -x 
	[ "$_symlink2data" -eq "0" ] && copyfiles "$_hourlyUsageDB" "$_hourlyUsageWWW"

}
getHourlyHeader(){
	send2log "=== getHourlyHeader ===" -1

	[ "$_debugging" -eq "1" ] && set +x 
	local meminfo=$(cat /proc/meminfo)
	local freeMem=$(getMI "$meminfo" "MemFree")
	local bufferMem=$(getMI "$meminfo" "Buffers")
	local cacheMem=$(getMI "$meminfo" "Cached")
	local availMem=$(($freeMem+$bufferMem+$cacheMem))
	local disk_utilization=$(df $_baseDir | grep -o "[0-9]\{1,\}%")
	[ "$_debugging" -eq "1" ] && set -x 
	send2log "  getHourlyHeader:_totMem-->$_totMem" -1

	echo "
var hourly_updated=\"$2\"
var users_updated=\"$_usersLastMod\"
var disk_utilization=\"$disk_utilization\"
var serverUptime=\"$1\"
var freeMem=\"$freeMem\",availMem=\"$availMem\",totMem=\"$_totMem\"
serverloads(\"$sl_min\",\"$sl_min_ts\",\"$sl_max\",\"$sl_max_ts\")

"
}

getPND(){
	send2log "=== getPND ===" -1
	[ "$_debugging" -eq "1" ] && set +x 
	local br0=$(grep -i "$_lan_iface" /proc/net/dev | tr -s ': ' ' ')
	send2log "  *** PND: br0: [$br0]" -1
 	local br_d=$(echo $br0 | cut -d' ' -f10)
	local br_u=$(echo $br0 | cut -d' ' -f2)
	[ "$br_d" == '0' ] && br_d=$(echo $br0 | cut -d' ' -f11)
	[ "$br_u" == '0' ] && br_u=$(echo $br0 | cut -d' ' -f3)
	[ -z "$br_d" ] && br_d=0
	[ -z "$br_u" ] && br_u=0
	[ "$_debugging" -eq "1" ] && set -x
	send2log "  *** PND: br_d: $br_d  br_u: $br_u" -1
	
	local ip4=$(getForwardData 'iptables' $YAMON_IP4)
	local ip6=''
	[ "$_includeIPv6" -eq "1" ] && ip6=$(getForwardData 'ip6tables' $YAMON_IP6)

	local result="pnd({\"hour\":\"$1\",\"uptime\":$2,\"down\":$br_d,\"up\":$br_u,\"lost\":$_totalLostBytes,\"hr-loads\":\"$hr_min1,$hr_min5,$hr_max5,$hr_max1\"$ip4$ip6})"
	echo "$result"
}
setUsers(){
	send2log "=== setUsers ===" -1
	_usersFile="$_dataPath$_usersFileName"
	[ "$_symlink2data" -eq "0" ] && _usersFileWWW="$_wwwPath$_wwwData$_usersFileName"
	
	[ ! -f "$_usersFile" ] && createUsersFile
	_currentUsers=$(cat "$_usersFile" | sed -e "s~(dup) (dup)~(dup)~Ig")
	[ "$_includeBridge" -eq "1" ] && checkBridge
	local lipe=$(echo "$_currentUsers" | grep "\b$_lan_ipaddr\b")
	[ -z "$lipe" ] && [ ! -z "$_lan_ipaddr" ] && add2UsersJS $_lan_hwaddr $_lan_ipaddr 0
	local nm=$(iptables -vnxL "$YAMON_IP4" | grep -c "\b$_lan_ipaddr\b")
	[ ! -z "$_lan_ipaddr" ] && checkIPTableEntries "iptables" "$YAMON_IP4" "$_lan_ipaddr" $nm

	lipe=$(echo "$_currentUsers" | grep "\b$_wan_ipaddr\b")
	[ -z "$lipe" ] && [ ! -z "$_wan_ipaddr" ] && add2UsersJS $_wan_hwaddr $_wan_ipaddr 0
	local nm=$(iptables -vnxL "$YAMON_IP4" | grep -c "\b$_wan_ipaddr\b")
	[ ! -z "$_wan_ipaddr" ] && checkIPTableEntries "iptables" "$YAMON_IP4" "$_wan_ipaddr" $nm

	send2log "	  started-->$started  _includeIPv6-->$_includeIPv6  " -1
	[ "$started" -eq "0" ] && checkUsers4IP
	send2log "  _currentUsers -->
$_currentUsers" -1
}
checkUsers4IP()
{
	send2log "=== checkUsers4IP ===" -1
	local ccd=$(echo "$_currentUsers" | grep 'users_created' | cut -d= -f2)
	ccd=${ccd//\"/}
	[ -z "$ccd" ] && ccd=$(date +"%Y-%m-%d %H:%M:%S")
	IFS=$'\n'
	local ncu="var users_created=\"$ccd\"
	"
	local nline=''
	[ "$_debugging" -eq "1" ] && set +x 
	local cdl=$(echo "$_currentUsers" | grep 'ud_a')
	[ "$_debugging" -eq "1" ] && set -x 
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
	[ ! -z "$dups" ] && [ "$_allowMultipleIPsperMAC" -eq "0" ] && send2log "There are duplicated mac addresses in $_usersFile:
$dups" 99
	_currentUsers="$ncu"
	save2File "$_currentUsers" "$_usersFile"
}
createUsersFile()
{
	send2log "=== createUsersFile ===" -1
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local users=''
	send2log "  >>> Creating empty users file: $_usersFile" -1
	touch $_usersFile
	chmod 666 $_usersFile
	users="var users_created=\"$ds\""
}
setFirmware()
{
	send2log "=== setFirmware ===" -1
	if [ "$_firmware" -eq "0" ] ; then 
		_lan_iface=$(nvram get lan_ifname)
		_lan_ipaddr=$(nvram get lan_ipaddr)
		_lan_hwaddr=$(nvram get lan_hwaddr | tr '[A-Z]' '[a-z]')
		_wan_ipaddr=$(nvram get wan_ipaddr)
		#_wan_gateway=$(nvram get wan_gateway)
		_wan_hwaddr=$(nvram get wan_hwaddr | tr '[A-Z]' '[a-z]')
		_conntrack="/proc/net/ip_conntrack"
	fi
	if [ "$_firmware" -eq "0" ] && [ "$_includeIPv6" -eq "0" ] ; then
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$1,$1 == "tcp" ? $5 : $4,$1 == "tcp" ? $7 : $6,$1 == "tcp" ? $6 : $5,$1 == "tcp" ? $8 : $7; } END { print "[ null ] ]"}'
	elif [ "$_firmware" -eq "0" ]; then #DD-WRT
		_conntrack="/proc/net/nf_conntrack"
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$3 == "tcp" ? $7 : $6,$3 == "tcp" ? $9 : $8,$3 == "tcp" ? $8 : $7,$3 == "tcp" ? $10 : $9; } END { print "[ null ] ]"}'
	elif [ "$_firmware" -eq "1" ]; then #OpenWRT
		_lan_iface="br-lan"
		_conntrack="/proc/net/nf_conntrack"
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$3 == "tcp" ? $7 : $6,$3 == "tcp" ? $9 : $8,$3 == "tcp" ? $8 : $7,$3 == "tcp" ? $10 : $9; } END { print "[ null ] ]"}'
	elif [ "$_firmware" -eq "2" ]; then #AsusWRT
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$3 == "tcp" ? $7 : $6,$3 == "tcp" ? $9 : $8,$3 == "tcp" ? $8 : $7,$3 == "tcp" ? $10 : $9; } END { print "[ null ] ]"}'
	elif [ "$_firmware" -eq "3" ]; then #Tomato
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$3 == "tcp" ? $7 : $6,$3 == "tcp" ? $9 : $8,$3 == "tcp" ? $8 : $7,$3 == "tcp" ? $10 : $9; } END { print "[ null ] ]"}'
	fi
}
checkBridge()
{
	send2log "=== checkBridge ===" -1
	[ "$_debugging" -eq "1" ] && set +x 
	local foundBridge=$(echo "$_currentUsers" | grep -i "$_bridgeMAC")
	[ -z "$foundBridge" ] && add2UsersJS $_bridgeMAC $_bridgeIP 0
	[ "$_debugging" -eq "1" ] && set -x 
}
setConfigJS()
{
	send2log "=== setConfigJS ===" -1
	local configjs="$_wwwPath$_wwwJS$_configWWW"
	local processors=$(grep -i processor /proc/cpuinfo -c)

	#Check for directories
	if [ ! -f "$configjs" ] ; then
		send2log "  >>> $_configWWW not found... creating new file: $configjs" 2
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
	[ "$_debugging" -eq "1" ] && set +x 
	[ ! "$_dbkey" == "" ] && configtxt="$configtxt
var _dbkey='$_dbkey'"
	save2File "$configtxt" "$configjs"
	
	[ "$_debugging" -eq "1" ] && set -x 
	send2log "  >>> configjs --> $configjs" -1
	send2log "  >>> configtxt --> $configtxt" -1
}
shutDown(){
	#one last backup before shutting down
	send2log "=== shutDown ===" 1
	
	updateHourly
	[ "$_symlink2data" -eq "0" ] && [ "$_dowwwBU" -eq 1 ] && doFinalBU

	send2log "
	=====================================
	\`yamon.sh\` has been stopped.
	-------------------------------------" 2
	write2log
	set +x
}

changeDates()
{
	send2log "	 >>> date change: $_pDay --> $_cDay " 1
	updateHourly2Monthly $_cYear $_cMonth $_pDay &
	
	local avrt='n/a'
	[ "$_dailyiterations" -gt "0" ] && avrt=$(echo "$_totalDailyRunTime $_dailyiterations" | awk '{printf "%.3f \n", $1/$2}')
	send2log "	 >>> Daily stats:  day-> $_pDay  #iterations--> $_dailyiterations   total runtime--> $_totalDailyRunTime   Ave--> $avrt	min-> $_daily_rt_min   max--> $_daily_rt_max" 1
	_hriterations=0
	_dailyiterations=0
	_totalhrRunTime=0
	_totalDailyRunTime=0
	_hr_rt_max=''
	_hr_rt_min=''
	_daily_rt_max=''
	_daily_rt_min=''
	_IPChanges=''
	
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
	write2log

	_cMonth=$(date +%m)
	_cYear=$(date +%Y)
	_ds="$_cYear-$_cMonth-$_cDay"
	if [ "$_unlimited_usage" -eq "1" ] ; then
		_ul_start=$(date -d "$_unlimited_start" +%s);
		_ul_end=$(date -d "$_unlimited_end" +%s);
		[ "$_ul_end" -lt "$_ul_start" ] && _ul_start=$((_ul_start - 86400))
		send2log "	  _unlimited_usage-->$_unlimited_usage ($_unlimited_start->$_unlimited_end / $_ul_start->$_ul_end)" 1
	fi

	setLogFile
	updateServerStats
	setDataDirectories
	_pDay="$_cDay"
	send2log "	>>> Flushing iptables chains..." 0
	$(iptables -F "$YAMON_IP4")
	[ ! -z "$_lan_ipaddr" ] && checkIPTableEntries "iptables" "$YAMON_IP4" "$_lan_ipaddr" 0
	[ ! -z "$_wan_ipaddr" ] && checkIPTableEntries "iptables" "$YAMON_IP4" "$_wan_ipaddr" 0
	if [ "$_includeIPv6" -eq "1" ] ; then
		$(ip6tables -F "$YAMON_IP6")
		[ ! -z "$_lan_ip6addr" ] && checkIPTableEntries "ip6tables" "$YAMON_IP6" "$ip6" 0
	fi
}
checkIPs()
{
	send2log "=== checkIPs ===" 0
	_changesInUsersJS=0
	checkIPv4 $YAMON_IP4
	[ "$_includeIPv6" -eq "1" ] && checkIPv6
	if [ "$_changesInUsersJS" -gt "0" ] ; then
		send2log "	>>> $_changesInUsersJS changes in users.js" 1 
		save2File "$_currentUsers" "$_usersFile"
	fi
}

checkIPv4()
{
	send2log "=== checkIPv4 ===" -1
	[ "$_debugging" -eq "1" ] && set +x 
	local ipl="$(eval "$_getIP4List")"
	local ipv4=$(getMACIPList "iptables" "$YAMON_IP4" "$ipl")
	[ "$_debugging" -eq "1" ] && set -x 
	send2log "	>>> ipv4 -> 
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
	send2log "=== checkIPv6 ===" -1
	[ "$_debugging" -eq "1" ] && set +x
	local ipl="$(eval "$_getIP6List")"	
	local ipv6=$(getMACIPList "ip6tables" "$YAMON_IP6" "$ipl")
	[ "$_debugging" -eq "1" ] && set -x
	send2log "	>>> ipv6 ->
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
	send2log "  === CheckUsersJS ===" -1
	send2log "	  Arguments: $1 $2 $3" -1
	
	local mac=$1
	local ip=$2
	local is_ipv6=$3
	local tip=${ip//\./\\.}
	if [ "$_includeBridge" -eq "1" ] && [ "$mac" == "$_bridgeMAC" ] ; then
		[ "$_debugging" -eq "1" ] && set +x
		local ipcount=$(echo "$_currentUsers" | grep -ic "\b$tip\b")
		if [ "$ipcount" -eq 0 ] ;  then
			send2log "	--- matched bridge mac but no matching entry for $ip.  Data will be tallied under bridge mac" 1
		elif [ "$ipcount" -eq 1 ] ;  then
			mac=$(echo "$_currentUsers" | grep -i "\b$tip\b" | grep -io '\([a-z0-9]\{2\}\:\)\{5,\}[a-z0-9]\{2\}')
			send2log "	--- matched bridge mac and found a unique entry for associated IP: $ip.  Changing MAC from $_bridgeMAC (bridge) to $mac (device)" 1
		else
			send2log "	--- matched bridge mac but found $ipcount matching entries for $ip.  Data will be tallied under bridge mac" 1
		fi
		[ "$_debugging" -eq "1" ] && set -x
	fi
	
	[ "$_debugging" -eq "1" ] && set +x
	local cu_no_dup=$(echo "$_currentUsers" | grep -v "$ip (dup)")
	local mie=$(echo "$cu_no_dup" | grep -i "$mac" | grep -ic "\b$tip\b")
	local ie=$(echo "$cu_no_dup" | grep -ic "\b$tip\b")
	if [ "$mie" -eq "1" ] ; then
		send2log "	>>> $mac & $ip exist in users.js" -1   
		[ "$ie" -gt "1" ] && clearDupIPs $ip $ie
		return
	fi
	local me=$(echo "$_currentUsers" | grep -ic "$mac")
	send2log "  mac: $mac	ip: $ip	mie-->$mie	me-->$me	ie-->$ie" 0
	[ "$ie" -gt "1" ] && clearDupIPs $ip $ie

	if [ "$me" -eq "0" ] ; then
		send2log "	>>> $mac does not exist in users.js... adding a new entry" 1 
		send2log "	  _currentUsers before:
$_currentUsers" -1
		add2UsersJS $mac $ip $is_ipv6
	elif [ "$_allowMultipleIPsperMAC" -eq "0" ] ; then
		if [ "$me" -eq "1" ] ; then
			send2log "	>>> $mac exists in users.js... updating existing unique entry" 1
			updateinUsersJS "$mac" "$ip" "$is_ipv6"
		else
			send2log "There are $me entries for $mac in users.js but it should be unique" 2 
		fi
	elif [ "$_allowMultipleIPsperMAC" -eq "1" ]; then
		send2log "	>>> multiple ips are allowed for $mac in users.js... adding a new entry" 1
		add2UsersJS $mac $ip $is_ipv6
	fi
	local line=$(echo "$_currentUsers" | grep -i "$mac" )
	[ "$_debugging" -eq "1" ] && set -x
	send2log "  changed line-->$line" -1
}
clearDupIPs()
{
	send2log "  === clearDupIPs ===" -1
	local ip=$1
	local ie=$2
	send2log "	>>> $ie other instance(s) of $ip exist in users.js... removing duplicate(s)" 1
	[ "$_debugging" -eq "1" ] && set +x
	local tip=${ip//\./\\.}
	_currentUsers=$(echo "$_currentUsers" | sed -e "s~\b$tip\b~$ip (dup)~Ig" | sed -e "s~(dup) (dup)~(dup)~Ig")
	[ "$_debugging" -eq "1" ] && set -x
}
updateinUsersJS()
{
	send2log "=== updateinUsersJS ===" -1
	send2log "  arguments: $1 $2 $3" -1
	
	local mac=$1
	local new_ip=$2
	local is_ipv6=$3

	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	[ "$_debugging" -eq "1" ] && set +x
	local line=$(echo "$_currentUsers" | grep -i "$mac" )
	[ "$_debugging" -eq "1" ] && set -x
	send2log "	  line1-->$line" -1
	
	if [ -z "$line" ] ; then
		send2log "updateinUsersJS: Could not find $mac in _currentUsers... this should not be possible?!? " 2
		return
	fi
	local old_ip=''
	[ "$is_ipv6" -eq 0 ] && ips='ip' || ips='ip6'
	
	old_ip=$(getField "$line" "$ips")
	line=$(replace "$line" "$ips" "$new_ip")
	line=$(replace "$line" "updated" "$ds")
	_currentUsers=$(echo "$_currentUsers" | sed -e "s~.\{0,\}\"$mac\".\{0,\}~$line~Ig")
	_changesInUsersJS=$(($_changesInUsersJS + 1))
	send2log "  >>> Device $mac & $old_ip ($is_ipv6) was updated to was updated to $mac & $new_ip 
$line" 1
	[ "$_debugging" -eq "1" ] && set +x
	send2log " _IPChanges before-->$_IPChanges" 0
	#_IPChanges=$(echo "$_IPChanges" | grep -v "(dup)" | grep -v "$new_ip.\{0,\}~.\{0,\}$new_ip" | grep -v "$old_ip.\{0,\}~" | grep -v "$new_ip.\{0,\}~.\{0,\}$old_ip")
	#local oiid =$(echo "$old_ip" | grep " (dup) ")
	#[ ! -z "$old_ip" ] && [ ! -z "$oiid" ] && _IPChanges="$_IPChanges
#$old_ip~$new_ip"
	send2log " _IPChanges after-->$_IPChanges" 1
	[ "$_debugging" -eq "1" ] && set -x
}
add2UsersJS()
{
	send2log "=== add2UsersJS ===" -1
	local mac=$1
	local ip=$2
	local is_ipv6=$3
	local kvs=''
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local deviceName=$(getDeviceName $mac)
	send2log "		deviceName-->$deviceName" -1
	if [ -z "$_do_separator" ] ; then
		local oname="$_defaultOwner"
		local dname="$deviceName"
	else
		local oname=${deviceName%%"$_do_separator"*}
		local dname=${deviceName#*"$_do_separator"}
	fi
	[ -z "$dname" ] || [ "$dname" == '*' ] && dname="$_defaultDeviceName"
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
	send2log "New device $dname (group $oname) was added to the network: $mac & $ip ($is_ipv6)" 99
	send2log "		newuser-->$newuser" -1
	_changesInUsersJS=$(($_changesInUsersJS + 1))
	_currentUsers="$_currentUsers
$newuser"
	send2log "	  _currentUsers-->$_currentUsers" -1
}
getDeviceName()
{
	send2log "=== getDeviceName ===" -1
	local mac=$1

	if [ "$_firmware" -eq "0" ] ; then
		[ "$_debugging" -eq "1" ] && set +x
		local nvr=$(nvram show 2>&1 | grep -i "static_leases=")
		#local result=$(echo "$nvr" | grep -io "$mac=.\{1,\}=" | cut -d= -f2)
		local result=$(echo "$nvr" | grep -io "$mac[^=]*=.\{1,\}=.\{1,\}=" | cut -d= -f2) 
		[ "$_debugging" -eq "1" ] && set -x
	elif [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] ; then
		# thanks to Robert Micsutka for providing this code & easywinclan for suggesting & testing improvements!
		local ucihostid=$(uci show dhcp | grep -i $mac | cut -d. -f2) 
		[ -n "$ucihostid" ] && local result=$(uci get dhcp.$ucihostid.name)
	elif [ "$_firmware" -eq "2" ] ; then
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
		[ "$_debugging" -eq "1" ] && set +x
		#local result=$(echo "$nvr" | grep -io "$mac=.\{1,\}=.\{1,\}=" | cut -d= -f3)
		local result=$(echo "$nvr" | grep -io "$mac[^=]*=.\{1,\}=.\{1,\}=" | cut -d= -f3) 
		[ "$_debugging" -eq "1" ] && set -x
	fi
	[ "$_debugging" -eq "1" ] && set +x 
	[ -z "$result" ] && [ -f "$_dnsmasq_conf" ] && result=$(echo "$(cat $_dnsmasq_conf | grep -i "dhcp-host=")" | grep -i "$mac" | cut -d, -f2)
	[ -z "$result" ] && [ -f "$_dnsmasq_leases" ] && result=$(echo "$(cat $_dnsmasq_leases)" | grep -i "$mac" | tr '\n' ' / ' | cut -d' ' -f4)
	[ "$_debugging" -eq "1" ] && set -x 
	echo "$result"
}
checkTimes()
{
	send2log "=== checkTimes ===" 0
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
	send2log "  _inUnlimited-->$_inUnlimited	_p_inUnlimited-->$_p_inUnlimited   currTime-->$currTime   _ul_start-->$_ul_start   _ul_end-->$_ul_end" -1
	
	[ "$_inUnlimited" -eq "1" ] && [ "$_p_inUnlimited" -eq "0" ] && send2log "	--- starting unlimited usage interval: $_unlimited_start" 1
	[ "$_inUnlimited" -eq "0" ] && [ "$_p_inUnlimited" -eq "1" ] && send2log "	--- ending unlimited usage interval: $_unlimited_end" 1
	_p_inUnlimited=$_inUnlimited

}
changeHour()
{
	local hr="$1"
	send2log "	 >>> hour change: $_p_hr --> $hr " 0
	local avrt='n/a'
	[ "$_hriterations" -gt "0" ] && avrt=$(echo "$_totalhrRunTime $_hriterations" | awk '{printf "%.3f \n", $1/$2}')
	send2log "	 >>> Hourly stats:  hr-> $_p_hr  #iterations--> $_hriterations   total runtime--> $_totalhrRunTime   Ave--> $avrt	min-> $_hr_rt_min   max--> $_hr_rt_max" 1
	_dailyiterations=$(($_dailyiterations+$_hriterations))
	_totalDailyRunTime=$(($_totalDailyRunTime+$_totalhrRunTime))
	_daily_rt_max=$(maxI $_daily_rt_max $_hr_rt_max )
	_daily_rt_min=$(minI $_daily_rt_min $_hr_rt_min )
	send2log "_thisHrpnd ($_p_hr): $_thisHrpnd" 1

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
		send2log "_thisHrdata: ($_p_hr)
$_thisHrdata" 1
		_hourlyData="$_hourlyData
$_thisHrdata"
		send2log "_thisHrpnd: ($_p_hr)
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
	send2log "=== updateServerStats === " 0
	[ "$_debugging" -eq "1" ] && set +x 
	local cTime=$(date +"%T")
	[ "$_debugging" -eq "1" ] && set -x 
	if [ -z "$sl_max" ] || [ "$sl_max" \< "$load5" ]; then
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
	[ "$_debugging" -eq "1" ] && set +x 
	send2log "=== doliveUpdates === ($_liveFilePath)" 0
	local loadavg=$(cat /proc/loadavg)
	send2log "  >>> loadavg: $loadavg" -1
	load1=$(echo "$loadavg" | cut -f1 -d" ")
	load5=$(echo "$loadavg" | cut -f2 -d" ")
	local load15=$(echo "$loadavg" | cut -f3 -d" ")
	local cTime=$(date +"%T")
	echo "var last_update='$_cYear/$_cMonth/$_cDay $cTime'
serverload($load1,$load5,$load15)" > $_liveFilePath

	if [ "$_doCurrConnections" -eq "1" ] ; then
		send2log "	>>> curr_connections" -1
		awk "$_conntrack_awk" "$_conntrack" >> $_liveFilePath
	fi
	
	send2log "	>>> _liveusage: $_liveusage" -1
	echo "$_liveusage" >> $_liveFilePath
	_liveusage=''
	[ "$_debugging" -eq "1" ] && set -x 
}
checkConfig()
{
	send2log "=== checkConfig ===" 0
	local _configMd5=$(md5sum $_configFile | cut -f1 -d" ")
	[ "$started" -eq "1" ] && send2log "  >>> _configMd5 --> $_configMd5   _savedconfigMd5 --> $_savedconfigMd5  " -1

	if [ "$_configMd5" == "$_savedconfigMd5" ] ; then
		send2log '  >>> _configMd5 == _savedconfigMd5' -1
		return
	fi
	_savedconfigMd5="$_configMd5"
	send2log "--- config.file has changed!  Resetting setInitValues ---" 2
	setConfigJS
	[ "$_enable_ftp" -eq 1 ] && send2FTP "$_configFile"
	updateHourly
	setInitValues
}
lostBytes()
{
	local nb=$2
	[ -z "$nb" ] && nb=0
	send2log "	  +++ lostBytes-->$_totalLostBytes ($2)" -1
	_totalLostBytes=$(digitAdd "$_totalLostBytes" "$nb")
	send2log "$1 (_totalLostBytes=$_totalLostBytes / $2)" 2
}
update()
{
	send2log "	  +++ update" -1
	send2log "	  arguments: $1 $2 $3 $4" -1
	
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	
	local ip="${1%/128}"
	local tip=${ip//\./\\.}
	local do="$2"
	local up="$3"
	local hr="$4"
	local bytes=$(digitAdd "$do" "$up")
	[ "$_debugging" -eq "1" ] && set +x
	local cu_no_dup=$(echo "$_currentUsers" | grep -vi "$tip (dup)")
	local cuc=$(echo "$cu_no_dup" | grep -ic "\b$tip\b")
	[ "$_debugging" -eq "1" ] && set -x
	if [ "$cuc" -eq 0 ] ; then
		local p_ip=$(echo "$_IPChanges" | grep -i "^$tip" | cut -d'~' -f2)
		send2log "   no mac-a   ip-->$ip   p_ip-->$p_ip" 1
		if [ "$ip" == "$p_ip" ] ; then
			send2log "Duplicate IPs: $ip ** $p_ip" 1
			send2log "$_IPChanges" 0
			lostBytes "	  !!! Infinite loop in IPChanges for $ip?!? returning " $bytes 
			return
		elif [ ! -z "$p_ip" ] ; then
			send2log "No matching entry in _currentUsers for $ip... trying again with $p_ip" 1
			update "$p_ip" "$do" "$up" "$hr"
			return
		fi
		lostBytes "	  !!! No matching entry in _currentUsers for $ip?!? returning " $bytes 
		send2log "$_currentUsers" -1
		return
	elif [ "$cuc" -gt 1 ] ; then
		lostBytes "	  !!! $cuc matching entries in _currentUsers for $ip?!? returning " $bytes 
		return
	fi
	local pdo=0
	local pup=0

	local new_do=$do
	local new_up=$up
	[ "$_debugging" -eq "1" ] && set +x
	local cu=$(echo "$cu_no_dup" | grep -i "\b$tip\b")
	[ "$_debugging" -eq "1" ] && set -x
	local mac=$(getField "$cu" 'mac')
	if [ -z "$mac " ] ; then
		send2log "		  cu-->$cu" -1
		local p_ip=$(echo "$_IPChanges" | grep "^$tip" | cut -d' ' -f2)
		send2log "   no mac-b   ip-->$ip   p_ip-->$p_ip" 1
		if [ "$ip" == "$p_ip" ] ; then
			send2log "Duplicate IPs: $ip ** $p_ip" 1
			send2log "$_IPChanges" 0
			lostBytes "	  !!! Infinite loop in IPChanges for $ip?!? returning " $bytes 
			return
		elif [ ! -z "$p_ip" ] ; then
			send2log "No matching entry in _currentUsers for $ip... trying again with $p_ip" 1
			update "$p_ip" "$do" "$up" "$hr"
			return
		fi
		lostBytes "	  !!! No matching MAC in _currentUsers for $ip?!? returning " $bytes 
		return
	elif [ "$mac" == "00:00:00:00:00:00" ] || [ "$mac" == "failed" ] || [ "$mac" == "incomplete" ] ; then
		send2log "  >>> skipping null/invalid MAC address for $ip" 0 
		return
	fi
	_liveusage="$_liveusage
curr_users({mac:'$mac',ip:'$ip',down:$do,up:$up})"
	[ "$_ignoreGateway" -eq "1" ] && [ "$mac" == "$_gatewayMAC" ] && return
	[ "$_debugging" -eq "1" ] && set +x
	local cur_hd=$(echo "$_thisHrdata" | grep -i "\"$mac\".\{0,\}\"$hr\"")
	[ "$_debugging" -eq "1" ] && set -x
	if [ -z "$cur_hd" ] ; then
		if [ "$_inUnlimited" -eq "0" ] ; then
			cur_hd="hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up"})"
		else
			cur_hd="hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up","\"ul_do\":$new_do,\"ul_up\":$new_up"})"
		fi
		send2log "	  new ul row-->$cur_hd" 1 
		_thisHrdata="$_thisHrdata
$cur_hd"
		return
	fi
	[ "$_debugging" -eq "1" ] && set +x
	local hasUL=$(echo "$cur_hd" | grep "ul_do")
	[ "$_debugging" -eq "1" ] && set -x
	pdo=$(getCV "$cur_hd" "down")
	pup=$(getCV "$cur_hd" "up")
	new_do=$(digitAdd "$do" "$pdo")
	new_up=$(digitAdd "$up" "$pup")
	if [ "$_inUnlimited" -eq "1" ] || [ ! -z "$hasUL" ]; then
		local pul_do=$(getCV "$cur_hd" "ul_do")
		local pul_up=$(getCV "$cur_hd" "ul_up")
		local new_ul_do=$(digitAdd "$do" "$pul_do")
		local new_ul_up=$(digitAdd "$up" "$pul_up")
		cur_hd="hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up","\"ul_do\":$new_ul_do,\"ul_up\":$new_ul_up"})"
	else   
		cur_hd="hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up"})"
	fi
	send2log "		  updated ul row-->$cur_hd" -1 
	[ "$_debugging" -eq "1" ] && set +x
	_thisHrdata=$(echo "$_thisHrdata" | sed -e "s~.\{0,\}\"$mac\".\{0,\}\"$hr\".\{0,\}~$cur_hd~Ig")
	[ "$_debugging" -eq "1" ] && set -x
}
updateUsage()
{
	local cmd=$1
	local chain=$2
	send2log "=== updateUsage ($cmd/$chain)=== " 0
	local hr=$(date +%H)
	_ud_list=''
	local iptablesData=$($cmd -L "$chain" -vnxZ | tr -s '[\-]' ' ' | grep "^\s[1-9]" | cut -d' ' -f3,8,9)
	if [ -z "$iptablesData" ] ; then
		send2log "	>>> $cmd returned no data... returning " 0 
		return
	fi
	createUDList "$iptablesData"
	send2log "iptablesData-->
$iptablesData" -1
	send2log "_ud_list-->
$_ud_list" -1

	IFS=$'\n'
	for line in $(echo "$_ud_list")
	do
		send2log "  >>> line-->$line" -1
		local ip=$(echo "$line" | cut -d',' -f1)
		local do=$(echo "$line" | cut -d',' -f2)
		local up=$(echo "$line" | cut -d',' -f3)
		update "$ip" "$do" "$up" "$hr"
	done
	unset IFS
}
updateHourly()
{
	send2log "=== updateHourly === " 0
	local hr=$(date +%H)
	[ "$_debugging" -eq "1" ] && set +x 
	local upsec=$(cat /proc/uptime | cut -d' ' -f1)
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local hourlyHeader=$(getHourlyHeader "$upsec" "$ds")
	_thisHrpnd=$(getPND "$hr" "$upsec")

	send2log "  _hourlyData--> $_hourlyData" -1
	send2log "  _thisHrdata--> $_thisHrdata" 0
	send2log "  _pndData-> $_pndData" -1
	send2log "  _thisHrpnd-> $_thisHrpnd" 0
	local nht="$_hourlyCreated
$hourlyHeader

$_hourlyData
$_thisHrdata

$_pndData
$_thisHrpnd"
	save2File "$nht" "$_hourlyUsageDB"
	[ "$_enable_db" -eq 1 ] && send2DB "hourly" "$_thisHrdata"
	[ "$_enable_db" -eq 1 ] && send2DB "pnd" "$_thisHrpnd"
	[ "$_debugging" -eq "1" ] && set -x 
}

runtimestats()
{
	send2log "=== runtimestats === $_totalhrRunTime $runtime $_hriterations" 0
	_totalhrRunTime=$(($_totalhrRunTime + $runtime))
	_hriterations=$(($_hriterations + 1))
	_hr_rt_max=$(maxI $_hr_rt_max $runtime )
	_hr_rt_min=$(minI $_hr_rt_min $runtime )
	send2log "=== runtimestats done === " -1
}
# ==========================================================
#				  Main program
# ==========================================================


d_baseDir=`dirname $0`

if [ ! -d "$d_baseDir/includes" ] || [ ! -f "$d_baseDir/includes/defaults.sh" ] || [ ! -f "$d_baseDir/includes/util.sh" ]  ; then
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

source "$d_baseDir/includes/defaults.sh"
source "$d_baseDir/includes/util.sh"
source "$d_baseDir/includes/hourly2monthly.sh"
_configFile="$d_baseDir/config.file"
source "$_configFile"
loadconfig
_debugging=0
[ "$_debug" -ge "$DB_ALL" ] && _debugging=1 && echo 'Debugging...' && set -x 

source "$d_baseDir/strings/$_lang/strings.sh"

[ ! -f "$_configFile" ] && echo "$_s_noconfig" && exit 0

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
_p_hr=-1
_totMem=''
_totalLostBytes=0
_changesInUsersJS=0
_IPChanges=''
_hriterations=0
_liveusage=''
_ndAMS=0
_ndAMS_dailymax=24
_log_str=''
started=0
sl_max=""
sl_max_ts=""
sl_min=""
sl_min_ts=""
_iteration=0

[ -d "$_lockDir" ] && echo "$_s_running" && exit 0

oc=$(iptables -L FORWARD | grep 3temp)
[ ! -z "$oc" ] && iptables -E "3temp" "$YAMON_IP4"

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
send2log "
**********************************************************
*  YAMon $_version was started
**********************************************************
" 2
write2log
timealign=$(($_updatefreq-$(date +%s)%$_updatefreq))
send2log "  >>> Delaying ${timealign}s to align updates" 1
sleep  "$timealign";
_p_hr=$(date +%H)
send2log "  >>> Starting main loop" 1

[ "$_debugging" -eq "0" ] && [ "$_debug" -ge "$DB_MOST" ] && _debugging=1 && set -x 
while [ -d $_lockDir ]; do
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
		write2log
		_log_str=''
	fi

	end=$(date +%s)
	runtime=$(($end-$start))
	offset=$(($start%$_updatefreq))
	pause=$(($_updatefreq-$runtime-$offset>0?$_updatefreq-$runtime-$offset:0))
	
	runtimestats
	
	send2log "  >>> #$_iteration - Execution time: $runtime seconds - pause: $pause seconds ($_hr_rt_min/$_hr_rt_max)" -1
	[ "$runtime" -gt "$_updatefreq" ] && send2log "	 Execution time exceeded delay (${runtime}s)!" 2
	sleep "$pause"

	[ ! -d "$_lockDir" ] && shutDown
		
done & 