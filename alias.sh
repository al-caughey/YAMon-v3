#!/bin/sh
##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# some useful aliases and shortcuts
# run: manually
# History
# 2020-01-03: 4.0.6 - added fix (to launch run-fixes.sh)
# 2019-12-23: 4.0.5 - added blocked alias; separated block & unblock; added duration option to block and unblock; added syntax description and rudimentary error trapping for group name
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################
alias clearlog='> /tmp/yamon/yamon.log'
alias comp='/opt/YAMon4/compare.sh'
alias copylog='/opt/YAMon4/copy-log.sh'
alias cpa="cp /opt/YAMon4/alias.sh $HOME/.profile ; . $HOME/.profile"
alias fif='/opt/YAMon4/fif.sh $1'
alias fix='/opt/YAMon4/run-fixes.sh'
alias ipt='iptables -L YAMONv40 -vnx'
alias ip6='ip6tables -L YAMONv40 -vnx'
alias pau='/opt/YAMon4/pause.sh'
alias psg="pscpa | grep -v grep | grep -i -e VSZ -e"
alias psy='ps | grep -v grep | grep YAMon'
alias sta='/opt/YAMon4/start.sh'
alias setp='/opt/YAMon4/setPaths.sh'
rr(){
	/opt/YAMon4/$1.sh
}
blocked(){
	local bt=$(iptables -L | grep blocked -B 2)
	if [ -z "$bt" ] ; then
		echo ">>>Nothing is currently blocked"
	else
		echo -e ">>>The following chains are currently blocked:\n$bt"
	fi
}
block(){
	chainName=${1:-Unknown}
	status='DROP'
	duration=${2:-0}
	gpl=$(echo $( iptables -L | grep 'Chain YAMONv40_' | awk '{print $2}' | cut -d'_' -f2))


	if [ -z "${1}" ] ; then
		echo -e "block --> prevent devices from accessing the web

Syntax: block <group> [<duration>]
 - <group>: group name as defined in the YAMon reports (see below)
 - <duration> [optional]: length of time (in minutes) to restrict access
    (if null, access will be blocked indefinitely or until the end of 
     the next scheduled blockage)

Currently defined groups: "
		echo ' -->' ${gpl// /, }
		echo ''
		return
	fi

	echo "Blocking: $chainName"
	
	if [ -z "$(echo $gpl | grep "\b$chainName\b")" ] ; then
		echo "Uh oh!!!! \`$chainName\` does not appear in the current list of groups
--> ${gpl// /, }"
		return
	fi
	
	/opt/YAMon4/block.sh "$chainName" "$status" "$duration"
	iptables -L YAMONv40_$1 | grep -v "^target"
}
unblock(){
	chainName=${1:-Unknown}
	status='RETURN'
	duration=${2:-0}
	gpl=$(echo $( iptables -L | grep 'Chain YAMONv40_' | awk '{print $2}' | cut -d'_' -f2))


	if [ -z "${1}" ] ; then
		echo -e "unblock --> allow blocked devices to access the web

Syntax: unblock <group> [<duration>]
 - <group>: group name as defined in the YAMon reports (see below)
 - <duration> [optional]: length of time (in minutes) to allow access
    (if null, access will be allowed indefinitely or until the start of 
     the next scheduled blockage)

Currently defined groups: "
		echo ' -->' ${gpl// /, }
		echo ''
		return
	fi

	echo "Unblocking: $chainName"
	
	if [ -z "$(echo $gpl | grep "\b$chainName\b")" ] ; then
		echo "Uh oh!!!! \`$chainName\` does not appear in the current list of groups
--> ${gpl// /, }"
		return
	fi

	/opt/YAMon4/block.sh "$chainName" "$status" "$duration"
	iptables -L YAMONv40_$1 | grep -v "^target"
	
}
echo '************************************************
************* Bash Aliases loaded **************
************************************************
'
