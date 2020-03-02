##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# various utility functions (shared between one or more scripts)
#
# History
# 3.2.1 (2017-01-28): moved setWebDirectories from yamon.x.sh to util.3.2
# 3.2.2 (2017-01-29): removed write2log; removed unused debugging calls
# 3.2.3 (2017-01-29): added line to remove symlink
# 3.2.4 (2017-02-20): no changes... updated for consistency
# 3.2.5 (2017-02-20): added generic user 0.0.0.0/0
# 3.2.6 (2017-02-26): spacing in prompt
##########################################################################

_enableLogging=1
_log2file=1
_scrlevel=1
_loglevel=0

showmsg()
{
	local wm=$1
	msg="$(cat "$d_path2strings$wm" )"
	[ ! -z "$2" ] && msg=$(echo "$msg" | sed -e "s~\%1\%~$2~g" )
	[ ! -z "$3" ] && msg=$(echo "$msg" | sed -e "s~\%2\%~$3~g" )
	[ ! -z "$4" ] && msg=$(echo "$msg" | sed -e "s~\%3\%~$4~g" )
	echo -e "$msg"
}

prompt()
{
	local resp
	local vn=$1
	eval nv=\"\$$vn\"
	local df="$4"
	local regex="$5"
	_qn=$(($_qn + 1))
	echo -e "
********************************
#$_qn. $2
" >&2
local p3="$3"
[ ! -z "$p3" ] && p3="    $p3
"

	if [ -z $nv ] && [ -z $df ] ; then
		nv='n/a'
		df='n/a'
		readStr="$p3    - type your preferred value --> "
	elif [ -z $df ] ; then
		readStr="$p3    - hit <enter> to accept the current value: \`$nv\`, or
    - type your preferred value --> "
	elif [ -z $nv ] ; then
		nv='n/a'
		readStr="$p3    - hit <enter> to accept the default: \`$df\`, or
    - type your preferred value --> "
	elif [ "$df" == "$nv" ] ; then
		readStr="$p3    - hit <enter> to accept the current/default value: \`$df\`, or
    - type your preferred value --> "
	else
		readStr="$p3    - hit <enter> to accept the current value: \`$nv\`, or
    - type \`d\` for the default: \`$df\`, or
    - type your preferred value --> "
	fi
	local tries=0
	while true; do
		read -p "$readStr" resp
		[ ! "$df" == 'n/a' ] && [ "$resp" == 'd' ] && resp="$df" && break
		[ ! "$nv" == 'n/a' ] && [ -z "$resp" ] && resp="$nv" && break
		[ "$nv" == 'n/a' ] && [ ! "$df" == 'n/a' ] && [ -z "$resp" ] && resp="$df" && break
		if [ ! -z "$regex" ] ;  then
			ig=$(echo "$resp" | grep -E $regex)
			[ ! "$ig" == '' ] && [ "$resp" == 'n' ] || [ "$resp" == 'N' ] && resp="0" && break
			[ ! "$ig" == '' ] && [ "$resp" == 'y' ] || [ "$resp" == 'Y' ] && resp="1" && break
			[ ! "$ig" == '' ] && break
		else
			break
		fi
		tries=$(($tries + 1))
		if [ "$tries" -eq "3" ] ; then
			echo "*** Strike three... you're out!" >&2
			exit 0
		fi
		echo "    Please enter one of the specified values!" >&2
	done
	eval $vn=\"$resp\"
	updateConfig $vn "$resp"
}
updateConfig(){
	local vn=$1
	local nv=$2
	[ "${vn:0:2}" == 't_' ] && return
	[ -z "$nv" ] && eval nv="\$$vn"
	echo "	  $vn --> $nv" >> $_logfilename
	local sv="$vn=.*#"
	local rv="$vn=\'$nv\'"
	local sm=$(echo "$configStr" | grep -o $sv)
	local l1=${#sm}
	local l2=${#rv}
	#echo "updateConfig: sm--> $sm ($l1)// rv--> $rv ($l2)" >&2
	local spacing='==================================================='
	if [ -z "$sm" ] ; then
		local pad=${spacing:0:$((55-$l2+1))}
		pad=${pad//=/ }
		configStr="$configStr
$vn='$nv'$pad # Added"
	#echo "updateConfig: $vn='$nv'$pad# Added" >&2
	else
		local pad=${spacing:0:$((55-$l2+1))}
		pad=${pad//=/ }
		configStr=$(echo "$configStr" | sed -e "s~$sv~$rv$pad#~g")
	fi
	#echo "updateConfig: configStr--> $configStr" >&2
}
getDefault(){
	eval vv=\$"options$1"
	local rv=$(echo "$vv" | cut -d, -f$(($2+1)))
	[ -z "$rv" ] && rv=$(echo "$vv" | cut -d, -f1)
	echo "$rv"
}
copyfiles(){
	local src=$1
	local dst=$2
	$(cp -a $src $dst)
	local res=$?
	if [ "$res" -eq "1" ] ; then
		local pre='  !!!'
		local pos=' failed '
	else
		local pre='  >>>'
		local pos=' successful'
	fi
	local lvl=$(($res+1))
	send2log "$pre Copy from $src to $dst$pos ($res)" $lvl
}
db()
{
	local n=$1
	eval v=\"\$$n\"
	echo "$n -->$v" >&2
}

send2log()
{
	local ll=$2
	[ -z "$ll" ] && ll=0
	if [ "$_enableLogging" -gt "0" ] ; then
		local ts=$(date +"%H:%M:%S")
		#[ "$ll" -ge "$_loglevel" ] && [ "$_log2file" -gt "0" ] && _log_str="$_log_str
#$_ds	$ts $ll	$1"
		[ "$ll" -ge "$_loglevel" ] && [ "$_log2file" -gt "0" ] && echo -e "$_ds\t$ts\t$ll\t$1" >> $_logfilename
		[ "$ll" -ge "$_scrlevel" ] && [ "$_log2file" -ne "1" ] && echo -e "$ts $ll $1" >&2
		[ "$ll" -eq "99" ] && [ "$_sendAlerts" -gt "0" ] && sendAlert "YAMon Alert..." "$1"
	fi
}
setWebDirectories()
{
	send2log "=== setWebDirectories ===" -1
	[ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] && [ ! -h "$_wwwPath" ] && ln -s "/tmp/www" "$_wwwPath"
	if [ "$_symlink2data" -eq "1" ] ; then
		if [ ! -d "$_wwwPath" ] ; then
			mkdir -p "$_wwwPath"
			chmod -R a+rX "$_wwwPath"
		fi
		if [ "${_logDir:0:1}" == "/" ] ; then
			local lfpath=$_logDir
		else
			local lfpath="${_baseDir}$_logDir"
		fi

		[ ! -d "$_wwwPath$_wwwJS" ] && mkdir -p "$_wwwPath$_wwwJS"
		local lcss=${_wwwCSS%/}
		local limages=${_wwwImages%/}
		local ldata=${_wwwData%/}
		local ljs=${_wwwData%/}
		local llogs='logs'

		[ -h "${_wwwPath}${_setupWebIndex}" ]  && rm -fv "${_wwwPath}${_setupWebIndex}"
		[ -h "${_wwwPath}${ldata}" ]  && rm -fv "${_wwwPath}${ldata}"

		[ ! -h "$_wwwPath$lcss" ] && ln -s "${_baseDir}$_setupWebDir$lcss" "$_wwwPath$lcss"
		[ ! -h "$_wwwPath$limages" ] && ln -s "${_baseDir}$_setupWebDir$limages" "$_wwwPath$limages"
		[ ! -h "$_wwwPath$ldata" ] && ln -s "$_dataPath" "$_wwwPath$ldata"
		[ ! -h "$_wwwPath$llogs" ] && ln -s "$lfpath" "$_wwwPath$llogs"
		[ ! -h "$_wwwPath$_setupWebIndex" ] && ln -s "${_baseDir}$_setupWebDir$d_setupWebIndex" "$_wwwPath$_setupWebIndex"
		[ ! -h "$_wwwPath$_wwwJS$_configWWW" ] && ln -s "${_baseDir}$_setupWebDir$_wwwJS$_configWWW" "$_wwwPath$_wwwJS$_configWWW"
	elif [ "$_symlink2data" -eq "0"  ] ; then
		[ ! -d "$_wwwPath$_wwwJS" ] && mkdir -p "$_wwwPath$_wwwJS"
		copyfiles "${_baseDir}$_setupWebDir*" "$_wwwPath"
	fi

	if [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ]  ; then
		local lan_ip=$(ifconfig br-lan | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
	else
		local lan_ip=$(nvram get lan_ipaddr)
	fi
	local lwww=$(basename $_wwwPath)
	echo "

	~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	~  Your reports URL: http://${lan_ip}/$lwww/$_setupWebIndex
	~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	send2log "Reports URL: http://${lan_ip}/$lwww/$_setupWebIndex" 1
}
getMI()
{
	#echo "getMI --> $1" >&2
	local result=$(echo "$1" | grep -i "^$2:" | grep -o "[0-9]\{1,\}")
	[ -z $result ] && result=0
	echo "$result"
	#echo "getMI result --> $result" >&2
}
sendAlert()
{
	send2log "=== sendAlert ===" 0
	local subj="$1"
	local omsg="$2"
	[ -z "$ndAMS" ] && ndAMS=0
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	msg="$omsg \n\n Message sent: $ds"

	if [ -z "$_sendAlertTo" ] ; then
		send2log "sendAlert:: _sendAlertTo is null... cannot send message
	subj: $subj
	msg: $omsg" 2
		return
	elif [ "$ndAMS" -eq "$_ndAMS_dailymax" ] ; then
		send2log "sendAlert:: reached daily alerts max... cannot send subj: $subj  msg: $omsg" 2
		subj="Please check your YAMon Settings!"
		msg="You have reached your maximum alerts allocation (max $_ndAMS_dailymax messages per day).  This typically means that there is something wrong in your settings or configuration.  Please contact Al if you have any questions."
	elif [ "$ndAMS" -gt "$_ndAMS_dailymax" ] ; then
		send2log "sendAlert:: exceeded daily alerts max... cannot send subj: $subj  msg: $omsg" 0
		return
	fi
	if [ "$_sendAlerts" -eq "1" ] ; then
		subj=${subj//\'/`}
		msg=${msg//\'/`}
		local url="http://usage-monitoring.com/current/sendmail.php"
		if [ -x /usr/bin/curl ] ; then
			curl -G -sS "$url" --data-urlencode "t=$_sendAlertTo" --data-urlencode "s=$subj" --data-urlencode "m=$msg"  > /tmp/sndm.txt
		else
			url="$url?t=$_sendAlertTo&s=$subj&m=$msg"
			local url=${url// /%20}
			wget "$url" -U "YAMon-Setup" -qO "/tmp/sndm.txt"
		fi
		local res=$(cat /tmp/sndm.txt)
	elif [ "$_sendAlerts" -eq "2" ] ; then
		ECHO=/bin/echo
		$ECHO -e "Subject: $subj\n\n$msg\n\n" | $_path2MSMTP -C $_MSMTP_CONFIG -a gmail $_sendAlertTo
		send2log "calling sendAlert via msmtp - subj: $subj  msg: $msg" 2
	fi
	ndAMS=$(($ndAMS+1))
}
getField()
{
	send2log "=== getField ===" 0
	send2log "	  arguments:  $1  $2" -1
	local line=$1
	local field=$2
	local result=$(echo "$line" | grep -o "$field\":\"[^\"]\{1,\}" | cut -d\" -f3)
	echo $result
}
getCV()
{
	send2log "=== getCV ===" 0
	send2log "	  arguments:  $1  $2" -1
	local result=$(echo "$1" | grep -io "\"$2\":[\"0-9]\{1,\}" | grep -o "[0-9]\{1,\}");
	[ -z $result ] && result=0

	echo "$result"
}
replace()
{
	send2log "=== replace ===" 0
	send2log "	  arguments:  $1  $2  $3" -1
	local line=$1
	local srch="\"$2\":\"[^\"]*\""
	local rplc="\"$2\":\"$3\""
	local result=$(echo $line | sed -e "s~$srch~$rplc~Ig" )
	echo "$result"
}
replaceNum()
{
	send2log "=== replaceNum ===" 0
	send2log "	  arguments:  $1  $2  $3" -1
	local line=$1
	local srch="\"$2\":[0-9]*"
	local rplc="\"$2\":$3"
	local result=$(echo $line | sed -e "s~$srch~$rplc~Ig" )
	echo "$result"
}
dailyBU()
{
	send2log "=== Daily Backups === " 0
	send2log "	  arguments:  $1  $2  $3" -1
	local bupath=$_dailyBUPath
	[ ! "${_dailyBUPath:0:1}" == "/" ] && bupath=${_baseDir}$_dailyBUPath

	if [ ! -d "$bupath" ] ; then
		send2log "  >>> Creating Daily BackUp directory - $bupath" 1
		mkdir -p "$bupath"
	fi
	local manifest="/tmp/manifest.txt"
	[ -f "$manifest" ] && touch "$manifest"
	local bu_ds=$1
	echo "$bu_ds
_usersFile: $_usersFile
_macUsageDB: $_macUsageDB
_hourlyUsageDB: $_hourlyUsageDB" > "$manifest"
	if [ "$_tarBUs" -eq "1" ]; then
		echo "logfilename: $_logfilename" >> "$manifest"
		send2log "  >>> Compressed back-ups for $bu_ds to $bupath"'bu-'"$bu_ds.tar" 0
		local bp="${bupath}bu-$bu_ds.tar"
		if [ "$_enableLogging" -eq "1" ] ; then

			tar -czf "$bp" "$manifest" "$_usersFile" "$_macUsageDB" "$_hourlyUsageDB" "$_logfilename" &
		else
			tar -czf "$bp" "$manifest" "$_usersFile" "$_macUsageDB" "$_hourlyUsageDB" &
		fi
		local return=$?
		if [ "$return" -ne "0" ] ; then
			send2log "  >>> Back-up compression for $bu_ds failed! Tar returned $return" 2
		else
			send2log "  >>> Back-ups for $bu_ds compressed - tar exited successfully." 1
		fi
	else
		local budir="$bupath"'bu-'"$bu_ds/"
		send2log "  >>> Copy back-ups for $bu_ds to $budir" 1
		[ ! -d "$bupath"'/bu-'"$bu_ds/" ] && mkdir -p "$budir"
		copyfiles "$_usersFile" "$budir"
		copyfiles "$_macUsageDB" "$budir"
		copyfiles "$_hourlyUsageDB" "$budir"
		[ "$_enableLogging" -eq "1" ] && copyfiles "$_logfilename" "$budir"
	fi
}

add2UDList(){
	send2log "=== add2UDList ===" 0
	send2log "	  arguments:  $1  $2  $3" -1
	local ip=$1
	local do=$2
	local up=$3
	local le=$(echo "$_ud_list" | grep -i "\b$ip\b")
	send2log "	  le-->$le" -1
	if [ -z "$le" ] ; then
		_ud_list="$_ud_list
$ip,$do,$up"
	else
		local pd=$(echo $le | cut -d',' -f2)
		local pu=$(echo $le | cut -d',' -f3)
		do=$(digitAdd "$do" "$pd")
		up=$(digitAdd "$up" "$pu")
		local tip=${ip//\./\\.}
		_ud_list=$(echo "$_ud_list" | sed -e "s~^$tip\b.*~$ip,$do,$up~Ig")
	fi
}
createUDList(){
	send2log "=== createUDList ===" -1
	send2log "	  arguments:  \$1-->$1" -1
	local results=''
	iptablesData="$1"
	IFS=$'\n'
	for line in $(echo "$iptablesData")
	do
		send2log "  >>> line-->$line" -1
		local f1=$(echo "$line" | cut -d' ' -f1)
		local f2=$(echo "$line" | cut -d' ' -f2)
		local f3=$(echo "$line" | cut -d' ' -f3)
		local isy=$(echo "$f1" | grep -i 'yamon')
		[ ! -z "$isy" ] && continue
		[ "$f1" -eq '0' ] && continue
		send2log "  >>> f1-->$f1	f2-->$f2   f3-->$f3   " -1
		if [ "$f2" == "0.0.0.0/0" ] || [ "$f2" == "::/0" ] ; then
			add2UDList $f3 $f1 0
		else
			add2UDList $f2 0 $f1
		fi
	done
	unset IFS
	#send2log "  >>> createUDList: _ud_list-->
#$_ud_list" 1
}
doFinalBU()
{
	send2log "=== doFinalBU ===" 0

	local ds=$(date +"%Y-%m-%d_%H-%M-%S")
	if [ "${_wwwBU:0:1}" == "/" ] ; then
		w3BUpath=$_wwwBU
	else
		w3BUpath=${_baseDir}$_wwwBU
	fi
	if [ ! -d "$w3BUpath" ] ; then
		send2log "  >>> Creating Web BackUp directory - $w3BUpath" -1
		mkdir -p "$w3BUpath"
	fi
	mkdir "$w3BUpath$ds"
	copyfiles "$_wwwPath" "$w3BUpath$ds"
}

maxF(){
	[ -z $1 ] && [ -z $2 ] && echo 0 && return
	[ -z $1 ] && echo $2 && return
	[ -z $2 ] && echo $1 && return
	[ "$1" \> "$2" ] && echo $1 && return
	echo $2
}
minF(){
	[ -z $1 ] && [ -z $2 ] && echo 0 && return
	[ -z $1 ] && echo $2 && return
	[ -z $2 ] && echo $1 && return
	[ "$1" \< "$2" ] && echo $1 && return
	echo $2
}
maxI(){
	[ -z $1 ] && [ -z $2 ] && echo 0 && return
	[ -z $1 ] && echo $2 && return
	[ -z $2 ] && echo $1 && return
	[ "$1" -gt "$2" ] && echo $1 && return
	echo $2
}
minI(){
	[ -z $1 ] && [ -z $2 ] && echo 0 && return
	[ -z $1 ] && echo $2 && return
	[ -z $2 ] && echo $1 && return
	[ "$1" -lt "$2" ] && echo $1 && return
	echo $2
}

checkIPTableEntries()
{
	clearIPs(){
		local cmd=$1
		local chain=$2
		local ip=$3
		[ "$ip" == "$g_ip" ] && return
		while [ true ]; do
			local dup_num=$($cmd -vnxL "$chain" --line-numbers | grep -m 1 -i "\b$ip\b" | cut -d' ' -f1)
			[ -z "$dup_num" ] && break
			$($cmd -D "$chain" $dup_num)
		done
	}
	addIP(){
		local cmd=$1
		local chain=$2
		local ip=$3
		clearIPs "$cmd" "$chain" "$g_ip\s*$g_ip"
		$($cmd -I "$chain" -s "$ip" -j RETURN)
		$($cmd -I "$chain" -d "$ip" -j RETURN)
		$($cmd -A "$chain" -s "$g_ip" -j RETURN)
		$($cmd -A "$chain" -d "$g_ip" -j RETURN)
	}
	clearIPs_t(){
		local cmd=$1
		local chain=$2
		local ip=$3
		[ "$ip" == "$g_ip" ] && return
		while [ true ]; do
			local dup_num=$($cmd -t mangle -vnxL "$chain" --line-numbers | grep -m 1 -i "\b$ip\b" | cut -d' ' -f1)
			[ -z "$dup_num" ] && break
			$($cmd -t mangle -D "$chain" $dup_num)
		done
	}
	addIP_t(){
		local cmd=$1
		local chain=$2
		local ip=$3
		clearIPs_t "$cmd" "$chain" "$g_ip\s*$g_ip"
		$($cmd -t mangle -I "$chain" -s "$ip" -j RETURN)
		$($cmd -t mangle -I "$chain" -d "$ip" -j RETURN)
		$($cmd -t mangle -A "$chain" -s "$g_ip" -j RETURN)
		$($cmd -t mangle -A "$chain" -d "$g_ip" -j RETURN)
	}
	send2log "=== checkIPTableEntries === " 0
	cmd=$1
	chain=$2
	ip=$3
	nm=$4
	g_ip="$_generic_ipv4"
	[ "$cmd" == 'ip6tables' ] && g_ip="$_generic_ipv6"


	if [ "$_useTMangle" -eq "0" ] && [ "$nm" -eq "0" ]; then
		send2log "  >>> Added rules to $chain for $mac-->$ip" 1
		addIP "$cmd" "$chain" "$ip"
	elif [ "$nm" -eq "0" ]; then
		send2log "  >>> Added rules to $chain for $mac-->$ip" 1
		addIP_t "$cmd" "$chain" "$ip"
	elif [ "$_useTMangle" -eq "0" ] ; then
		send2log "  !!! Incorrect number of rules for $ip in $chain -> $nm... removing duplicates" 99
		clearIPs "$cmd" "$chain" "$ip"
		addIP "$cmd" "$chain" "$ip"
	else
		send2log "  !!! Incorrect number of rules for $ip in $chain -> $nm... removing duplicates" 99
		clearIPs_t "$cmd" "$chain" "$ip"
		addIP_t "$cmd" "$chain" "$ip"
	fi
}
checkIPChain()
{
	send2log "=== checkIPChain === " 0
	local cmd="$1"
	local chain=$2
	local rule=$3
	send2log "=== check $cmd for $chain ===" 0
	if [ "$_useTMangle" -eq "0" ] ; then
		foundRule=$($cmd -L | grep -ic "chain $rule")
		foundChain=$($cmd -L "$chain" | grep -ic "\b$rule\b")
		if [ "$foundChain" -eq "1" ]; then
			send2log "  >>> Rule $rule exists in chain $chain ==> $foundChain" 0
		elif [ "$foundChain" -eq "0" ]; then
			send2log "  >>> Created rule $rule in chain $chain ==> $foundChain" 2
			[ "$foundRule" -eq "0" ] && $($cmd -N $rule) && sleep 2
			$($cmd -I "$chain" -j "$rule")
		else
			send2log "  !!! Found $foundChain instances of $rule in chain $chain... deleting them individually rather than flushing!" 99
			local i=1
			while [  "$i" -le "$foundChain" ]; do
				local dup_num=$($cmd -L "$chain" --line-numbers | grep -m 1 -i "\b$rule\b" | cut -d' ' -f1)
				$($cmd -D "$chain" $dup_num)
				i=$(($i+1))
			done
			$($cmd -I "$chain" -j "$rule")
		fi
	else
		foundRule=$($cmd -t mangle -L | grep -ic "chain $rule")
		foundChain=$($cmd -t mangle -L "$chain" | grep -ic "\b$rule\b")
		if [ "$foundChain" -eq "1" ]; then
			send2log "  >>> Rule $rule exists in chain $chain ==> $foundChain" 0
		elif [ "$foundChain" -eq "0" ]; then
			send2log "  >>> Created rule $rule in chain $chain ==> $foundChain" 2
			[ "$foundRule" -eq "0" ] && $($cmd -t mangle -N $rule)
			$($cmd -t mangle -I "$chain" -j "$rule")
		else
			send2log "  !!! Found $foundChain instances of $rule in chain $chain... deleting them individually rather than flushing!" 99
			local i=1
			while [  "$i" -le "$foundChain" ]; do
				local dup_num=$($cmd -t mangle -L $chain --line-numbers | grep -m 1 -i "\b$rule\b" | cut -d' ' -f1)
				$($cmd -t mangle -D $chain $dup_num)
				i=$(($i+1))
			done
			$($cmd -t mangle -I $chain -j $rule)
		fi
	fi
}
getMACIPList(){
	local cmd=$1
	local rule=$2
	send2log "=== getMACIPList ($cmd/$rule) === " 0
	if [ "$_useTMangle" -eq "0" ] ; then
		local rules=$(echo "$($cmd -nL "$rule" --line-numbers )" | grep '^[0-9]' | tr -s '-' ' ' | cut -d' ' -f1,4,5)
	else
		local rules=$(echo "$($cmd -t mangle -nL "$rule" --line-numbers )" | grep '^[0-9]' | tr -s '-' ' ' | cut -d' ' -f1,4,5)
	fi
	if [ -z "$rules" ] ; then
		send2log "	$rule returned nothing?!?" 2
		checkIPChain $cmd "FORWARD" $rule
		checkIPChain $cmd "INPUT" $rule
	fi
	send2log "	  rules-->
$rules" -1
	local list=$3
	local result
	IFS=$'\n'
	for line in $(echo "$list")
	do
		local ip=$(echo "$line" | cut -d' ' -f1)
		local tip=${ip//\./\\.}
		local mac=$(echo "$line" | cut -d' ' -f2)
		local nm=$(echo "$rules" | grep -ic "\b$tip\b" )
		[ "$nm" -ne "2" ] && checkIPTableEntries $cmd $rule $ip $nm

		local me=$(echo "$result" | grep $mac )
		if [ -z "$me" ] ; then
			result="$result
$mac $ip"
		else
			result=$(echo "$result" | sed -e "s~$mac ~$mac $ip,~Ig")
		fi
	done
	unset IFS
	echo "$result"
}

getForwardData(){
	local cmd="$1"
	local chain="$2"
	if [ "$_useTMangle" -eq "0" ] ; then
		local fc=$($cmd -L FORWARD -vnx | tr -s '-'  ' ' | sed 's~^\s*~~')
	else
		local fc=$($cmd -t mangle -L FORWARD -vnx | tr -s '-'  ' ' | sed 's~^\s*~~')
	fi
	ym=$(echo "$fc" | grep "$chain" | cut -d' ' -f2)
	[ -z "$ym" ] && ym=0
	l2w=$(echo "$fc" | grep "lan2wan" | cut -d' ' -f2)
	[ -z "$l2w" ] && l2w=0
	dp=$($cmd -L -vnx | tr -s '-' ' ' | sed 's~^\s*~~' | grep "DROP" | cut -d' ' -f2)
	IFS=$'\n'
	local tot=0
	for line in $(echo "$dp")
	do
		tot=$(digitAdd "$tot" "$line")
	done
	echo ", '$cmd': {\"$chain\":$ym,\"lan2wan\":$l2w,\"DROP\":$tot}"
}
save2File(){
	send2log "=== save2File === " 0
	if [ -z "$3" ] ;  then
		echo "$1" > "$2" #replace the file if param #3 is null
		send2log "save2File --> data saved to $2 " 1
	else
		echo "$1" >> "$2" #otherwise append to the file
		send2log "save2File --> data appended to $2 " 1
	fi
	[ "$_enable_ftp" -eq 1 ] && send2FTP "$2"
}
send2FTP(){
	send2log "=== send2FTP === " 0
	#local fname=${1##*/}
	local fname=$(echo "$1" | sed -e "s~$_baseDir$_setupWebDir~~Ig" | sed -e "s~$d_baseDir~~Ig" | sed -e "s~$_wwwPath~~Ig" | sed -e "s~$_dataDir~$_wwwData~Ig")
	if [ "${fname:0:1}" == "/" ] ; then
		local ftp_path="$_ftp_dir$fname"
	else
		local ftp_path="$_ftp_dir/$fname"
	fi
	ftpput -u "$_ftp_user" -p "$_ftp_pswd" "$_ftp_site" "$ftp_path" "$1"
	send2log "send2FTP --> $1 sent to FTP site ($ftp_path)" 1
}
send2DB(){
	local v=$(echo "$2" | tr '({' '(' | tr '})' ')' | tr '\n' '|')
	local url="$_db_url?t=${_db_name}&t=${1}&v=${v}"
	send2log "=== send2DB ==>$url"  1
	local results=$(wget -q -O - "$url")
	send2log "send2DB --> $results" 1
}