#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# Script to help set baseline values in config.file for YAMon3.x
#
##########################################################################

#HISTORY
# 3.3.0 (2017-06-18): bumped minor version; added xwrt, Turris
# 3.3.1 (2017-07-17): check/update value of _configWWW
# 3.3.1a (2017-07-19): fixed symlink paths in setWebDirectories
# 3.3.2 (2017-07-26): added check for SFE; more Tomato fixes
# 3.3.3 (2017-09-26): fixed d_baseDir; added prompts for '_doLiveUpdates' & '_doArchiveLiveUpdates'; improved Turris setup
# 3.3.4 (2017-10-10): check for nvram vs uci
# 3.3.5 (2017-11-05): added prompt for path to /tmp/www
# 3.4.0 (2018-02-04): added advanced vs basic mode; added prompt for bridge
# 3.4.1 (2018-02-19): updated a lot of the regexes for prompts
# 3.4.2 (2018-02-23): updated with fixes suggested by Jeff Page; added Padavan as a firmware variant
# 3.4.3 (2018-02-26): added optional 6th topic parameter for `prompt`
# 3.4.4 (2018-03-12): re-added a prompt for _path2ip

d_baseDir="${YAMON%/}"

[ -z "$d_baseDir" ] && d_baseDir=$(cd "$(dirname "$0")" && pwd)
[ -z "$directory" ] && delay=$1
[ -z "$delay" ] && delay=5
[ -z "$send2log" ] && send2log='send2log'

source "${d_baseDir}/includes/versions.sh"
source "${d_baseDir}/includes/util$_version.sh"

if [ ! -f "${d_baseDir}/config.file" ] && [ ! -f "${d_baseDir}/default_config.file" ] ; then
	$send2log '*** Cannot find either config.file or default_config.file...' 2
	echo '*** Cannot find either config.file or default_config.file...
*** Please check your installation! ***
*** Exiting the script. ***'
	exit 0
elif [ -f "${d_baseDir}/config.file" ] ; then
	_configFile="${d_baseDir}/config.file"
else
	_configFile="${d_baseDir}/default_config.file"
fi
configStr=$(cat "$_configFile")
source "$_configFile"
source "${d_baseDir}/includes/defaults.sh"
source "${d_baseDir}/strings/en/strings.sh"

[ -z "$_enableLogging" ] && _enableLogging=1
[ -z "$_log2file" ] && _log2file=1
[ -z "$_loglevel" ] && _loglevel=0

[ -n "$_canClear" ] && clear
echo "$_s_title"

echo "
$los
This script will guide you through the process of setting up the
basic parameters in your \`config.file\` for YAMon$_version.

See http://usage-monitoring.com/download.php for more detailed
instructions regarding the setup process.

NB - a number of the advanced (aka less commonly used) settings
    are not currently addressed in this script.

    If you want to use any of those features, you can edit your
    \`config.file\` directly (often without actually having to stop 
    & restart the main YAMon script).
$los
"
sleep $delay
_logDir='logs/'
_logfilename="${d_baseDir}/${_logDir}setup$_version.log"
echo "This script will create a log of the selections you make in the 
upcoming prompts.  The file name & path is:
  \`$_logfilename\`
If you encounter any issues during the setup process, please send your 
log and as much additional info to install@usage-monitoring.com.

"
sleep $delay
[ -n "$_canClear" ] && clear

[ ! -d "${d_baseDir}/$_logDir" ] && mkdir -p "${d_baseDir}/$_logDir"
[ ! -f "$_logfilename" ] && touch "$_logfilename"

$send2log "Launched setup.sh - v$_version" 1
echo "

You are running this script from \`$d_baseDir\`
with baseline settings from \`$_configFile\`"
$send2log "Baseline settings: \`$_configFile\`" 1

dd_str='DD-WRT'
op_str='OpenWrt'
le_str='LEDE'
tu_str='Turris'
am_str='ASUSWRT-Merlin'

_firmware=0
if [ -f "/etc/openwrt_release" ] ; then
	distro=$(cat /etc/openwrt_release | grep -i 'DISTRIB_ID' | cut -d"'" -f2)
	installedfirmware=$(cat /etc/openwrt_release | grep -i 'DISTRIB_DESCRIPTION' | cut -d"'" -f2)
	installedversion=''
	installedtype=''
	if [ "$distro" == "$le_str" ] ; then
		le_str='LEDE (*)'
		_firmware=4
	else
		tu_str='Turris (*)'
		_firmware=6
	
	fi
elif [ "$_has_nvram" == "1" ] ; then
	installedfirmware=$(uname -o)
	if [ "$installedfirmware" == "$dd_str" ] ; then
		_firmware=0
		dd_str='DD-WRT (*)'
	elif [ "$installedfirmware" == "$op_str" ] ; then
		op_str='OpenWrt (*)'
		_firmware=1
	elif [ "$installedfirmware" == "$am_str" ] ; then
		am_str='ASUSWRT-Merlin (*)'
		_firmware=2
	fi
	if [ $_firmware == 2 ] ; then
		routermodel=$(nvram get model)
		installedversion=$(nvram get buildno)_$(nvram get extendno)
		installedtype='merlin'
	else
		routermodel=$(nvram get DD_BOARD)
		installedversion=$(nvram get os_version)
		installedtype=$(nvram get dist_type)
	fi
fi

if [ -d /tmp/sysinfo/ ] ; then
	model=$(cat /tmp/sysinfo/model)
	board=$(cat /tmp/sysinfo/board_name)
	routermodel="$model $board"
fi

yn_y="Options: \`0\` / \`n\` ==> No -or- \`1\` / \`y\` ==> Yes (*)"
yn_n="Options: \`0\` / \`n\` ==> No (*) -or- \`1\` / \`y\` ==> Yes"
zo_r=^[01nNyY]$
zot_r=^[012]$
_qn=0
re_path=^.*$
re_path_slash=^.*/$


echo "

Router Model: $routermodel"
echo "Installed firmware: $installedfirmware $installedversion $installedtype"
$send2log "Router Model: $routermodel" 1
$send2log "Installed firmware: $installedfirmware $installedversion $installedtype" 1
routerfile="${d_baseDir}/www/js/router.js"

if [ -f "$routerfile" ] ; then
	installed=$(cat "$routerfile" | grep install | cut -d"'" -f2)
	updated=$(date +"%Y-%m-%d %H:%M:%S")
else
	installed=$(date +"%Y-%m-%d %H:%M:%S")
	updated=''
fi
echo "var installed='$installed'
var updated='$updated'
var router='$routermodel'
var firmware='$installedfirmware $installedversion $installedtype'
var version='$_version'" > $routerfile

sleep $delay

echo "
In the upcoming prompts, the recommended/default value will be 
denoted with an asterisk (*).  To accept the default, simply 
hit <enter>. Otherwise, type your preferred value & then hit <enter>.

NB - If you are updating from a previous version of YAMon, back up 
everything before proceeding!  This includes any customizations 
you've made to devices in the reports - see 
http://usage-monitoring.com/help/?t=export-users

First things first, this script now supports a basic and an advanced
setup mode... select basic if you are relatively new to this process
and have simple configuration on your router.
Select advanced if you are an experienced user and want more input
over the settings.
 "

t_installmode='b'
prompt 't_installmode' "Do you want run setup in Basic(*) or Advanced mode?" "In basic mode, the default settings will be selected.
    Advanced mode allows you to tailor the settings.
    Enter \`b\` for basic or \`a\` for advanced:" "$t_installmode" "^[aAbB]$" 'running-setup'
	
$send2log "Install mode: $t_installmode" 1

echo "

NB - You can always finetune your settings by editing
     \`config.file\` (in \`${d_baseDir}/config.file\`)."

[ "$_webDir" == "Setup/www/" ] && updateConfig "_webDir" "www/"
[ "$_webIndex" == "yamon2.html" ] && updateConfig "_webIndex" "index.html"
[ "$_webIndex" == "yamon3.html" ] && updateConfig "_webIndex" "index.html"
[ "$_webIndex" == "yamon3.1.html" ] && updateConfig "_webIndex" "index.html"
[ "$_webIndex" == "yamon3.2.html" ] && updateConfig "_webIndex" "index.html"
[ "$_wwwData" == "data/" ] || [ "$_wwwData" == "data" ] && updateConfig "_wwwData" "data3/"
[ "$_configWWW" == "config.js" ] && updateConfig "_configWWW" "config$_file_version.js"
[ "$_configWWW" == "config3.js" ] && updateConfig "_configWWW" "config$_file_version.js"
[ "$_liveFileName" == "live_data.js" ] && updateConfig "_liveFileName" "live_data3.js"

configStr=$(echo "$configStr" | sed -re "s~_configWWW='([^']{1,})'~_configWWW=\"\1\"~")

if  [ -n "$(echo "$configStr" | grep -e "^_setupWebDir")" ] ; then
	$send2log "Renamed _setupWebDir to _webDir" 1
	configStr="${configStr/_setupWebDir/_webDir}"
fi
if  [ -n "$(echo "$configStr" | grep -e "^_setupWebIndex")" ] ; then
	$send2log "Renamed _setupWebIndex to _webIndex" 1
	configStr="${configStr/_setupWebIndex/_webIndex}"
fi

prompt '_firmware' 'Which firmware variant is running on your router?' "Options:
    0 -> $dd_str
    1 -> $op_str
    2 -> $am_str
    3 -> Tomato
    4 -> $le_str
    5 -> Xwrt-Vortex
    6 -> $tu_str
	7 -> Padavan" $_firmware ^[0-7]$
	
if [ "$_firmware" == "0" ] ; then
	flags="{"
	lan_proto=$(nvram get lan_proto)
	$send2log "lan_proto --> $lan_proto" 1
	[ ! "$lan_proto" == "dhcp" ] && echo "
	$wrn
	$bl_a
	  ##   It appears that your router is not the DHCP Server for
	  ##   your network.
	  ##   YAMon gets its data via \`iptables\` calls.  They only
	  ##   return meaningful data from the DHCP Server.
	$bl_a
	  ##   You must enable this feature on this router if you want to use YAMon!
	$bl_a
	  ##   DD-WRT web GUI: \`Setup\`-->\`Basic Setup\` -->\`Network Address Server Settings (DHCP)\`
	$bl_a
	$loh" && sleep 5
	sfe_enable=$(nvram get sfe)
	$send2log "sfe_enable --> $sfe_enable" 1
	[ "$sfe_enable" == "1" ] && echo "
	$wrn
	$bl_a
	  ##   The \`Shortcut Forwarding Engine\` is enabled in your DD-WRT config.
	  ##   SFE alters the normal flow of packets through \`iptables\` and that
	  ##   prevents YAMon from accurately reporting the traffic on
	  ##   your router.
	$bl_a
	  ##   YAMon will not report properly if you do not disable this feature!
	$bl_a
	  ##   DD-WRT web GUI: \`Setup\`-->\`Basic Setup\` -->\`Optional Settings\`
	$bl_a
	$loh" && sleep 5

	upnp_enable=$(nvram get upnp_enable)
	$send2log "upnp_enable --> $upnp_enable" 1
	[ "$upnp_enable" == "1" ] && echo "
	$wrn
	$bl_a
	  ##   \`UPnP\` is enabled in your DD-WRT config.
	  ##   UPnP alters the normal flow of packets through \`iptables\` and that
	  ##   will likely prevent YAMon from accurately reporting the traffic on
	  ##   your router.
	$bl_a
	  ##   It is recommended that you disable this feature!
	$bl_a
	  ##   DD-WRT web GUI: \`NAT / QoS\`-->\`UPnP\` -->\`UPnP Configuration\`
	$bl_a
	$loh" && sleep 5

	privoxy_enable=$(nvram get privoxy_enable)
	$send2log "privoxy_enable --> $privoxy_enable" 1
	[ "$privoxy_enable" == "1" ] && echo "
	$wrn
	$bl_a
	  ##   \`Privoxy\` is enabled in your DD-WRT config.
	  ##   Privoxy alters the normal flow of packets through \`iptables\` and
	  ##   that *will* prevent YAMon from accurately reporting the traffic
	  ##   on your router.
	$bl_a
	  ##   YAMon will not report properly if you do not disable this feature!
	$bl_a
	  ##   DD-WRT web GUI: \`Services\`-->\`Adblocking\`-->\`Privoxy\`
	$bl_a
	$loh" && sleep 5

	ntp_enable=$(nvram get ntp_enable)
	$send2log "ntp_enable --> $ntp_enable" 1
	[ "$ntp_enable" == "1" ] && echo "
	$wrn
	$bl_a
	  ##   \`NTP Client\` is not enabled in your DD-WRT config.
	  ##   The NTP Client allows you to set your time zone and synchronize
	  ##   the clock on your router.
	$bl_a
	  ##   YAMon will likely not provide accurate reports if you do not
	  ##   enabled this feature!
	$bl_a
	  ##   DD-WRT web GUI: \`Setup\`-->\`Basic Setup\`-->\`Time Settings\`
	$bl_a
	$loh" && sleep 5

	schedule_enable=$(nvram get schedule_enable)
	schedule_hours=$(nvram get schedule_hours)
	schedule_minutes=$(nvram get schedule_minutes)
	schedule_reboot=0
	$send2log "schedule_enable --> $schedule_enable ($schedule_hours:$schedule_minutes)" 1
	[ "$schedule_enable" == "1" ] && [ "$schedule_hours" == "0" ] && [ "$schedule_minutes" -lt "10" ] && echo "
	$wrn
	$bl_a
	  ##   Your router is scheduled to auto-reboot at '$schedule_hours:$schedule_minutes'.
	  ##   This may interfere with the YAMon function that consolidates
	  ##   the daily totals into the monthly usage file.
	$bl_a
	  ##   If you must auto-reboot your router, please do so after ~12:15AM!
	$bl_a
	  ##   DD-WRT web GUI: \`Administration\`-->\`Keep Alive\`-->\`Schedule Reboot\`
	$bl_a
	$loh" && schedule_reboot=1 && sleep 5
	flags="{lan_proto:$lan_proto, sfe_enable:$sfe_enable upnp_enable:$upnp_enable, privoxy_enable:$privoxy_enable, ntp_enable:$ntp_enable, schedule_reboot:$schedule_reboot}"

fi

prompt '_ispBillingDay' 'What is your ISP bill roll-over date? 
    (i.e., on what day of the month does your usage reset to zero)' 'Enter the day number [1-31]' '' "^([1-9]|[12][0-9]|[3][01])$"
prompt '_monthlyDataCap' 'Does your data plan have a cap?' "(Options: \`0\` ==> Unlimited Plan(*) -or- \`##\` ==> your cap in GB [1-9999])" '0' "^[0-9]{1,4}$"
prompt '_unlimited_usage' 'Does your ISP offer `Bonus Data`?
    (i.e., uncapped data usage during offpeak hours)' "$yn_n" '0' $zo_r
if [ "$_unlimited_usage" == "1" ] ; then
	prompt '_unlimited_start' 'Start time for bonus data?' 'Enter the time in [hh:mm] format' '' "^(00|[1-9]|1[0-9]|2[0-3]):[0-5][0-9]$" '_unlimited_usage'
	prompt '_unlimited_end' 'End time?' 'Enter the time in [hh:mm] format' '' "^(00|[1-9]|1[0-9]|2[0-3]):[0-5][0-9]$" '_unlimited_usage'
fi
if [ "$t_installmode" == 'b' ] ; then
	
	[ "$_firmware" == "2" ] || [ "$_firmware" == "3" ] || [ "$_firmware" == "5" ] && updateConfig "_wwwPath" '/tmp/var/wwwext/'
	if [ "$_firmware" == "1" ] || [ "$_firmware" == "4" ] || [ "$_firmware" == "6" ] || [ "$_firmware" == "7" ] ; then
		lan_ip=$(uci get network.lan.ipaddr)
		[ -z "$lan_ip" ] && lan_ip=$(ifconfig br-lan | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
		updateConfig "_wwwURL" '/yamon'
	else
		lan_ip=$(nvram get lan_ipaddr)
	fi
	_dataPath="${d_baseDir}/$_dataDir"
	
else
	prompt '_includeBridge' 'Do you have a bridge on your network?
    (i.e., a second router or other device to extend the wireless range)' "$yn_n" '0' $zo_r
	if [ "$_includeBridge" == "1" ] ; then
		prompt '_bridgeMAC' 'What is the MAC address for your bridge device?
    See the help topic if you have multiple bridging devices' "Enter a valid MAC address - e.g., 11:22:33:44:55:66" '' "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$" '_includeBridge'
	fi
	t_wid=1
	prompt 't_wid' "Is your \`data\` directory in \`$d_baseDir\`?" "$yn_y" $t_wid $zo_r
	[ "$t_wid" == "0" ] && prompt '_dataDir' "Enter the path to your data directory" "Options:
	* to specify an absolute path, start with \`/\`
	* the path *must* end with \`/\`" "data/" $re_path_slash
	prompt '_updatefreq' 'How frequently would you like to check the data?' 'Enter the interval in seconds [1-300 sec]' '30' "^([1-9]|[1-9][0-9]|[1-2][0-9][0-9]|300)$"
	prompt '_publishInterval' 'How many checks between updates in the reports?' 'Enter the number of checks [must be a positive integer 1-99]' '2' "^([1-9]|[1-9][0-9])$"

	if [ -z "$(ip -6 neigh show)" ] ; then
		ipv6_enable=0
	else
		ipv6_enable=1
	fi
	$send2log "ipv6_enable --> $ipv6_enable" 1

	prompt '_includeIPv6' "Do you want to include IPv6 traffic?
    NB - your firmware *must* include a full version of \`ip\` (some don't!)" "$yn_n" "$ipv6_enable" $zo_r
	t_ip=0
	prompt 't_ip' 'Have you manually installed the full version of `ip` elsewhere on your router?' "$yn_n" $t_ip $zo_r '_path2ip'
	if [ "$t_ip" == "1" ] ; then
	   prompt '_path2ip' 'Where is the full version of `ip` installed?' 'The path must start with a \`/\`' '/opt/sbin/ip' $re_path '_path2ip'

		if [ ! -f "$_path2ip" ] ; then
			send2log "path to full ip \`$_path2ip\` is not correct" 2
			updateConfig "_path2ip" ""
			echo "
	*******************************************************
	*  \`$_path2ip\` does not exist... you must fix this before
	*   running this script... your results will not be correct!
	*******************************************************
	"
		fi
	fi

	if [ "$_firmware" == "1" ] || [ "$_firmware" == "4" ] || [ "$_firmware" == "6" ] || [ "$_firmware" == "7" ] ; then
		lan_ip=$(uci get network.lan.ipaddr)
		d_wwwPath='/www'
		[ -z "$lan_ip" ] && lan_ip=$(ifconfig br-lan | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
		[ "$_wwwURL" == '/user' ] && _wwwURL='/yamon'
	elif [ "$_firmware" == "2" ] || [ "$_firmware" == "3" ] || [ "$_firmware" == "5" ] ; then
		d_wwwPath='/tmp/var/wwwext/'
	else
		lan_ip=$(nvram get lan_ipaddr)
	fi

	[ -h "${_wwwPath}index.html" ] && rm -fv ${_wwwPath}index.html
	[ -h "${_wwwPath}data" ] && rm -fv ${_wwwPath}data
	[ -h "${_wwwPath}data3" ] && rm -fv ${_wwwPath}data3
	[ -h "${_wwwPath}data3.3" ] && rm -fv ${_wwwPath}data3.3
	[ -h "/www/user/user/" ] && rm -fv '/www/user/user/'
	[ -h "/www/user/" ] && rm -fv '/www/user/'
	[ -h "/tmp/www/www/" ] && rm -fv '/tmp/www/www/'

	prompt '_symlink2data' 'Create symbollic links to the web data directories?' "$yn_y" '1' $zo_r
	prompt '_wwwPath' 'Specify the path to the web directories?' 'The path must start and end with a `/`' "$d_wwwPath" $re_path_slash
	prompt '_wwwURL' "Specify the URL path to the reports - e.g. $lan_ip<path>?" 'The path must start and end with a `/`.  Do *NOT* enter the IP address!' "$d_wwwURL" $re_path_slash

	if [ "${_dataDir:0:1}" == "/" ] ; then
		_dataPath=$_dataDir
	else
		_dataPath="${d_baseDir}/$_dataDir"
	fi

	prompt '_organizeData' 'Organize the data files (into directories by year or year-month)?' 'Options: 0->No -or- 1->by year -or- 2->by year & month (*)' '2' $zot_r
	prompt '_enableLogging' 'Enable logging (for support & debugging purposes)?' "$yn_y" '1' $zo_r
	[ "$_enableLogging" == "1" ] && prompt '_log2file' 'Where do you want to send the logging info?' 'Options: 0->screen -or- 1->file (*) -or- 2->both' '1' $zot_r '_enableLogging'
	[ "$_enableLogging" == "1" ] && [ "$_log2file" -ne 0 ] && prompt '_logDir' 'Where do you want to create the logs directory?' 'Options:
    * to specify an absolute path, start with `/`
    * the path *must* end with `/`' 'logs/' $re_path_slash '_enableLogging'
	[ "$_enableLogging" == "1" ] && prompt '_loglevel' 'How much detail do you want in the logs?' 'Options: -1->really verbose -or- 0->all -or- 1->most (*) -or- 2->serious only' '1' "^([012]|-1)$" '_enableLogging'
	[ "$_log2file" == "2" ] || [ "$_log2file" == "2" ] && prompt '_scrlevel' 'How much detail do you want shown on the screen?' 'Options: -1->really verbose -or- 0->all -or- 1->most (*) -or- 2->serious only' '1' "^([012]|-1)$" '_enableLogging'

	prompt '_doLiveUpdates' 'Do you want to report `live` usage?' "$yn_y" '1' $zo_r
	[ "$_doLiveUpdates" == "1" ] && prompt '_doArchiveLiveUpdates' 'Do you want to archive the `live` usage data?' "$yn_n" '0' $zo_r '_doLiveUpdates'

	[ -z "$(which ftpput)" ] && [ "$_enable_ftp" == "1" ] && updateConfig "_enable_ftp" "0"
	[ -z "$(which ftpput)" ] || prompt '_enable_ftp' 'Do you want to mirror a copy of your data files to an external FTP site? 
	NB - *YOU* must setup the FTP site yourself!' "$yn_n" '0' $zo_r
	if [ -n "$(which ftpput)" ] && [ "$_enable_ftp" == "1" ] ; then
		prompt '_ftp_site' 'What is the URL for your FTP site?' 'Enter just the URL or IP address' '' '' '_enable_ftp'
		prompt '_ftp_user' 'What is the username for your FTP site?' '' '' '' '_enable_ftp'
		prompt '_ftp_pswd' 'What is the password for your FTP site?' '' '' '' '_enable_ftp'
		prompt '_ftp_dir' 'What is the path to your FTP storage directory?' "Options: ''->root level -or- enter path" '' '' '_enable_ftp'
		[ "$_organizeData" -gt "0" ] && echo "
    *******************************************************
    *  You will have to manually create the year/month
    *  sub-directories on your FTP site for the data files.
    *******************************************************
"
	fi
	prompt '_doDailyBU' 'Enable daily backup of data files?' "$yn_y" '1' $zo_r
	[ "$_doDailyBU" == "1" ] && prompt '_tarBUs' 'Compress the backups?' "$yn_y" '1' $zo_r '_doDailyBU'
fi

if [ ! -d "$_dataPath" ] ; then
	$send2log ">>> Creating data directory" 0
	mkdir -p "$_dataPath"
	chmod -R 666 "$_dataPath"
fi

setWebDirectories

if [ "$_firmware" == "1" ] || [ "$_firmware" == "4" ] || [ "$_firmware" == "6" ] || [ "$_firmware" == "7" ] ; then
	updateConfig "_dnsmasq_conf" "/tmp/etc/dnsmasq.conf"
	updateConfig "_dnsmasq_leases" "/tmp/dhcp.leases"
	_dnsmasq_conf="/tmp/etc/dnsmasq.conf"
	_dnsmasq_leases="/tmp/dhcp.leases"
elif [ "$_firmware" == "2" ] || [ "$_firmware" == "3" ] ; then
	updateConfig "_dnsmasq_conf" "/tmp/etc/dnsmasq.conf" 
	updateConfig "_dnsmasq_leases" "/tmp/var/lib/misc/dnsmasq.leases"
	_dnsmasq_conf="/tmp/etc/dnsmasq.conf"
	_dnsmasq_leases="/tmp/var/lib/misc/dnsmasq.leases"
fi

[ ! -f "$_dnsmasq_conf" ] && echo "  >>> specified path to _dnsmasq_conf ($_dnsmasq_conf) does not exist"
[ ! -f "$_dnsmasq_leases" ] && echo "  >>> specified path to _dnsmasq_leases ($_dnsmasq_leases) does not exist"

_configFile="${d_baseDir}/config.file"
if [ ! -f "$_configFile" ] ; then
	touch "$_configFile"
	$send2log "Created and saved settings in new file: \`$_configFile\`" 1
	echo "
******************************************************************
Created and saved settings in new file: \`$_configFile\`
******************************************************************"
else
	copyfiles "$_configFile" "${d_baseDir}/config.old"
	$send2log "Updated existing settings: \`$_configFile\`" 1
   echo "
    ******************************************************************
    * Copied previous configuration settings to \`${d_baseDir}/config.old\`
    * and saved new settings to \`$_configFile\`
    ******************************************************************"
fi

dirty=''
mfl=''
p_list=$(cat "${d_baseDir}/default_config.file" | grep -o "^_[^=]\{1,\}")

IFS=$'\n'
for line in $(echo "$p_list")
do
	dpe=$(echo "$configStr" | grep -i "^$line")
	#echo "dpe-->$dpe"
	[ -n "$dpe" ] && continue
	eval nv=\"\$$line\"
	[ -n "$nv" ] && [ "$nv" -ne '0' ] && echo "nv: *$nv*" && continue
	dvn="d$line"
	eval dv=\"\$$dvn\"
	dirty="true"
	mfl="$mfl
	* $line ($dv)"
	updateConfig "$line" "$dv"
done

[ -n "$dirty" ] && echo "
###########################################################
NB - One or more parameters were missing in your config.file!$mfl
The missing entries have been appended to that file with defaults
from \`default_config.file\`.

See \`default_config.file\` for more info about these values and check to ensure
that the defaults are appropriate for your network configuration.
###########################################################

"
echo "$configStr" > "$_configFile"

su="${d_baseDir}/startup.sh"
sd="${d_baseDir}/shutdown.sh"
ya="${d_baseDir}/yamon${_version}.sh"
h2m="${d_baseDir}/h2m.sh"
glc="${d_baseDir}/glc.sh"

t_perm="775"
t_perm_msg="e.g., $t_perm (*)-> rwxrwxr-x"
if [ "$t_installmode" == 'b' ] ; then
	chmod $t_perm -R "$d_baseDir"
	chmod $t_perm "$su"
	chmod $t_perm "$sd"
	chmod $t_perm "$ya"
	chmod $t_perm "$h2m"
	chmod $t_perm "$glc"
	chmod "$t_perm" -R "$_wwwPath"
	$send2log "Changed \`$_wwwPath\` permissions to: \`$t_perm\`" 1
	chmod "$t_perm" -R "${d_baseDir}/www"
	$send2log "Changed \`${d_baseDir}/www\` permissions to: \`$t_perm\`" 1
else
	perm_r=^[0-7][0-7][0-7]$
	prompt 't_permissions' "Do you want to set directory permissions for \`${d_baseDir}\`?" "$yn_y" '1' $zo_r
	if [ "$t_permissions" == "1" ] ; then
		prompt 't_perm' "What permission value do you want to use?" "$t_perm_msg" "$t_perm" $perm_r 't_permissions' 
		$send2log "Changed ${d_baseDir} permissions to: \`$t_perm\`" 1
	fi
	chmod $t_perm -R "$d_baseDir"
	chmod $t_perm "$su"
	chmod $t_perm "$sd"
	chmod $t_perm "$ya"
	chmod $t_perm "$h2m"
	chmod $t_perm "$glc"

	t_www=0
	
	if [ "$_firmware" == "1" ] || [ "$_firmware" == "4" ] || [ "$_firmware" == "6" ] || [ "$_firmware" == "7" ] ; then
		t_perm="a+rX"
		t_perm_msg="e.g., $t_perm (*)-> r-xr-xr-x"
		perm_r=^[0-7a-zA-z+]{3,4}$
		prompt 't_www' "Do you want to set directory permissions for \`${_wwwPath}\`?" "$yn_y" '1' $zo_r 't_permissions' 
	fi
	if [ "$t_www" == "1" ] ; then
		prompt 't_perm' "What permissions value do you want to use?" "$t_perm_msg" "$t_perm" $perm_r 't_permissions' 
		chmod "$t_perm" -R "$_wwwPath"
		$send2log "Changed \`$_wwwPath\` permissions to: \`$t_perm\`" 1
		chmod "$t_perm" -R "${d_baseDir}/www"
		$send2log "Changed \`${d_baseDir}/www\` permissions to: \`$t_perm\`" 1
	else
		chmod 664 -R "$_wwwPath"
	fi
fi
	startup_delay='10'
	[ "$t_installmode" == 'a' ] && prompt 'startup_delay' "By default, \`startup.sh\` will delay for 10 seconds prior to starting \`yamon${_version}.sh\`. 
		Some routers may require extra time." 'Enter the start-up  delay [0-300]' '10' "^([0-9]|[1-9][0-9]|[1-2][0-9][0-9]|300)$"

	if [ "$_firmware" == "1" ] ; then
		etc_init="/etc/init.d/yamon3"
		t_init=1
		[ "$t_installmode" == 'a' ] && prompt 't_init' 'Create YAMon init script in `/etc/init.d/`?' "$yn_y" '1' $zo_r
		if [ "$t_init" == "1" ] ; then
			$send2log "Created YAMon init script in `/etc/init.d/`" 1
			[ ! -d "/etc/init.d/" ] && mkdir -p "/etc/init.d/" # is this even necessary?
			echo "#!/bin/sh /etc/rc.common
	START=99
	STOP=10
	start() {
		# commands to launch application
		if [ -d "$_lockDir" ]; then
			echo "Unable to start, found $_lockDir directory"
			return 1
		fi
		${d_baseDir}/startup.sh 10 &
	}
	stop() {
		${d_baseDir}/shutdown.sh
		return 0
	}
	restart() {
		${d_baseDir}/restart.sh
		return 0
	}
	boot() {
		start
	}" > "$etc_init"
			chmod +x "$etc_init"
		fi
	elif [ "$_firmware" == "4" ] || [ "$_firmware" == "6" ] || [ "$_firmware" == "7" ] ; then
		etc_rc="/etc/rc.local"
		t_init=1
		[ "$t_installmode" == 'a' ] && prompt 't_init' 'Create YAMon init script in `/etc/rc.local`?' "$yn_y" '1' $zo_r
		if [ "$t_init" == "1" ] ; then
			$send2log "Created YAMon init script in $etc_rc" 1
			[ ! -f "$etc_rc" ] && touch "$etc_rc" # is this even necessary?
			c_txt=$(cat "$etc_rc")
			if [ -z "$(echo "$c_txt" | grep 'startup.sh')" ] ; then
			   sed -i "s~exit 0~${su} \nexit 0~g" "$etc_rc"
			else
				$send2log "Skipped adding startup.sh to $etc_rc" 1
				echo -e "
    etc_rc--> already contains the string \`startup.sh\`...
    \`$su\` was not added"
			fi
		fi
	else
		t_startup=1
		[ "$t_installmode" == 'a' ] && prompt 't_startup' 'Do you want to create startup and shutdown scripts?' "$yn_y" '1' $zo_r
		need2commit=''
		if [ "$t_startup" == "1" ] ; then
			cnsu=$(nvram get rc_startup)
			if [ -z "$cnsu" ] ; then
				$send2log "Created nvram-->rc_startup" 1
				echo "
    nvram-->rc_startup was empty... \`$su\` was added"
				nvram set rc_startup="$su $startup_delay"
				need2commit="true"
			elif [ -z "$(echo $cnsu | grep 'startup.sh')" ] ; then
				$send2log "Added to nvram-->rc_startup" 1
				echo "
    nvram-->rc_startup was not empty but does not contain the string \`startup.sh\`...
    \`$su\` was appended"
				nvram set rc_startup="$cnsu
	$su $startup_delay"
				need2commit="true"
			else
				$send2log "Skipped adding nvram-->rc_startup" 1
				echo -e "
		nvram-->rc_startup already contains the string \`startup.sh\`...
		\`$su\` was not added"
			fi
			cnsd=$(nvram get rc_shutdown)
			if [ -z "$cnsd" ] ; then
				$send2log "Created nvram-->rc_shutdown" 1
				echo "
    nvram-->rc_shutdown was empty... \`$sd\` was added"
				nvram set rc_shutdown="$sd"
				need2commit="true"
			elif [ -z "$(echo $cnsd | grep 'shutdown.sh')" ] ; then
				$send2log "Added to nvram-->rc_shutdown" 1
				echo "
    vram-->rc_shutdown was not empty but does not contain the string \`shutdown.sh\`...
    \`$sd\` was appended"
				nvram set rc_shutdown="$cnsd
	$sd"
				need2commit="true"
			else
				$send2log "Skipped nvram-->rc_shutdown" 1
				echo -e "
		nvram-->rc_shutdown already contains the string \`shutdown.sh\`...
		\`$sd\` was not added"
			fi
			[ -n "$need2commit" ] && nvram commit
		fi
	fi

	ip4=$(eval iptables -nL | grep "Chain $YAMON_IP4")
	[ -n "$ip4" ] && $(iptables -F "$YAMON_IP4")
	if [ "$_includeIPv6" == "1" ] ; then
		ip6=$(eval ip6tables -nL | grep "Chain $YAMON_IP6")
		[ -n "$ip6" ] && $(ip6tables -F "$YAMON_IP6")
	fi

prompt 't_launch' 'Do you want to launch YAMon now?' "$yn_y" '1' $zo_r
if [ "$t_launch" == "1" ] ; then
	$send2log "Launched " 1
	echo "

****************************************************************

[Re]starting YAMon$_version

"
	${d_baseDir}/restart.sh $startup_delay
	exit 0
fi

echo "

****************************************************************

YAMon$_version is now configured and ready to run.

To launch YAMon, enter \`${d_baseDir}/startup.sh\`.

Send questions to questions@usage-monitoring.com

Thank you for installing YAMon.  You can show your appreciation and support future development by donating at https://www.paypal.me/YAMon/.

Thx!	Al

"