#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-2016 Al Caughey
# All rights reserved.
#
# Script to help set baseline values in config.file for YAMon3.x
#
#   2016-03-19 - see To Do below
#
##########################################################################

# To Do:
# 
#HISTORY
# 3.1.1 (2016-10-10): added etc/init.d/yamon3 for OpenWrt as per michaeljprentice @ http://www.dd-wrt.com/phpBB2/viewtopic.php?p=1046901#1046901

d_baseDir="$YAMON"
[ -z "$d_baseDir" ] && d_baseDir="`dirname $0`/"
delay=$1
[ -z $delay ] && delay=5

_debugging=0  # set this value to 1 if Al tells you to... only needed if you are experiencing issues with this script
source "${d_baseDir}includes/util.sh"
_enableLogging=1
_log2file=1
_loglevel=0

echo "$_s_title"
sleep $delay
echo "
$los
This script will guide you through the process of setting up the
basic parameters in your \`config.file\`.

NB - a number of the advanced (aka less commonly used) settings
	 are not currently addressed in this script.

If you want to use any of those features, you can edit your
\`config.file\` directly (without actually having to stop the
YAMon script).
$los
"

[ ! -f "${d_baseDir}config.file" ] && [ ! -f "${d_baseDir}default_config.file" ] && echo '*** Cannot find either config.file or default_config.file...
	*** Please check your installation! ***
	*** Exiting the script. ***' && exit 0
sleep $delay

local nvram=$(nvram show 2>&1)
local upnp_enable=$(echo "$nvram" | grep -i 'upnp_enable=1')
[ ! -z "$upnp_enable" ] && echo "
$wrn
$bl_a
	##   \`UPnP\` is enabled in your DD-WRT config.
	##   UPnP alters the normal flow of packets through \`iptables\` and that  
	##   will likely prevent YAMon from accurately reporting the traffic on
	##   your router.
$bl_a
	##   It is recommended that you disable this option!
$bl_a
	##   DD-WRT web GUI: \`NAT / QoS\`-->\`UPnP\` -->\`UPnP Configuration\`
$bl_a
$loh" && sleep 5
local privoxy_enable=$(echo "$nvram" | grep -i 'privoxy_enable=1')
[ ! -z "$privoxy_enable" ] && echo "
$wrn
$bl_a
	##   \`Privoxy\` is enabled in your DD-WRT config.
	##   Privoxy alters the normal flow of packets through \`iptables\` and 
	##   that *will* prevent YAMon from accurately reporting the traffic
	##   on your router.
$bl_a
	##   If you want to use YAMon to monitor usage, you must disable Privoxy!
$bl_a
	##   DD-WRT web GUI: \`Services\`-->\`Adblocking\`-->\`Privoxy\`
$bl_a
$loh" && sleep 5

local ntp_enable=$(echo "$nvram" | grep -i 'ntp_enable=0')
[ ! -z "$ntp_enable" ] && echo "
$wrn
$bl_a
	##   \`NTP Client\` is not enabled in your DD-WRT config.
	##   The NTP Client allows you to set your time zone and synchronize
	##   the clock on your router.
$bl_a
	##   YAMon will likely not provide accurate reports if you do not
	##   enabled this option!
$bl_a
	##   DD-WRT web GUI: \`Setup\`-->\`Basic Setup\`-->\`Time Settings\`
$bl_a
$loh" && sleep 5

local schedule_enable=$(echo "$nvram" | grep -i 'schedule_enable=1')
local schedule_hr=$(echo "$nvram" | grep -i 'schedule_hours' | cut -d'=' -f2)
local schedule_min=$(echo "$nvram" | grep -i 'schedule_minutes' | cut -d'=' -f2)
[ ! -z "$schedule_enable" ] && [ "$schedule_hr" -eq "0" ] && [ "$schedule_min" -lt "10" ] && echo "
$wrn
$bl_a
	##   Your router is scheduled to auto-reboot at '$schedule_hr:$schedule_min'.
	##   This may interfere with the YAMon function that consolidates
	##   the daily totals into the monthly usage file.
$bl_a
	##   If you must auto-reboot your router, please do so after ~12:15AM!
$bl_a
	##   DD-WRT web GUI: \`Administration\`-->\`Keep Alive\`-->\`Schedule Reboot\`
$bl_a
$loh" && sleep 5

echo "You are running this script from \`$d_baseDir\`."

echo "
In the prompts below, the recommended value is denoted with
an asterisk (*).  To accept this default, simply hit <enter>;
otherwise type your preferred value (and then hit <enter>).
"

local yn_y="Options: \`0\` / \`n\` ==> No -or- \`1\` / \`y\` ==> Yes(*)"
local yn_n="Options: \`0\` / \`n\` ==> No(*) -or- \`1\` / \`y\` ==> Yes"
local zo_r=^[01nNyY]$
local zot_r=^[012]$
_qn=0

_configFile="${d_baseDir}config.file"
[ ! -f "$_configFile" ] && [ -f "${d_baseDir}default_config.file" ] && _configFile="${d_baseDir}default_config.file"
source "$_configFile"
loadconfig()
[ -f "$_configFile" ] && echo "Loading baseline settings from \`$_configFile\`."
configStr=$(cat "$_configFile")

_logfilename="${d_baseDir}$_logDir"'setup.log'
echo "Log file:  \`$_logfilename\`."
[ ! -d "${d_baseDir}$_logDir" ] && mkdir -p "${d_baseDir}$_logDir"
[ ! -f "$_logfilename" ] && touch "$_logfilename"

updateConfig "_baseDir" "$d_baseDir"
[ "$_setupWebDir" == "Setup/www/" ] && updateConfig "_setupWebDir" "www/"
[ "$_setupWebIndex" == "yamon2.html" ] && updateConfig "_setupWebIndex" "yamon3.html"
[ "$_setupWebIndex" == "yamon3.html" ] && updateConfig "_setupWebIndex" "yamon3.1.html"
[ "$_wwwData" == "data/" ] || [ "$_wwwData" == "data" ] && updateConfig "_wwwData" "data3/"
[ "$_configWWW" == "config.js" ] && updateConfig "_configWWW" "config3.js"
[ "$_liveFileName" == "live_data.js" ] && updateConfig "_liveFileName" "live_data3.js" 
prompt '_firmware' 'Which of the *WRT firmware variants is your router running?' 'Options: 
            0 -> DD-WRT(*)
            1 -> OpenWrt
            2 -> Asuswrt-Merlin
            3 -> Tomato
            4 -> LEDE' '0' ^[0-4]$
local t_wid=1
prompt 't_wid' "Is your \`data\` directory in \`$d_baseDir\`?" "$yn_n" $t_wid $zo_r
[ "$t_wid" -eq 0 ] && prompt '_dataDir' "Enter the path to your data directory" "Options: 
          * to specify an absolute path, start with \`/\`
          * the path *must* end with \`/\`" "data/" ^[a-z0-9\/]*/$
prompt '_ispBillingDay' 'What is your ISP bill roll-over date?' 'Enter the day number [1-31]' '' ^[1-9]$\|^[12][0-9]$\|^[3][01]$
prompt '_unlimited_usage' 'Does your ISP offer `Bonus Data`?\n	(i.e., uncapped data usage during offpeak hours)' "$yn_n" '0' $zo_r
[ "$_unlimited_usage" -eq 1 ] && prompt '_unlimited_start' 'Start time for bonus data?' 'Enter the time in [hh:mm] format' '' ^[1-9]:[0-5][0-9]$\|^1[0-2]:[0-5][0-9]$
[ "$_unlimited_usage" -eq 1 ] && prompt '_unlimited_end' 'End time?' 'Enter the time in [hh:mm] format' '' ^[1-9]:[0-5][0-9]$\|^[1][0-2]:[0-5][0-9]$
prompt '_updatefreq' 'How frequently would you like to check the data?' 'Enter the interval in seconds [1-300 sec]' '30' ^[1-9]$\|^[1-9][0-9]$\|^[1-2][0-9][0-9]$\|^300$
prompt '_publishInterval' 'How many checks between updates in the reports?' 'Enter the number of checks [must be a positive integer]' '2' ^[1-9]$\|^[1-9][0-9]$\|^[1-9][0-9][0-9]$

local ipv6_enable=$(echo "$nvram" | grep -i 'ipv6_enable=1')
if [ ! -z "$ipv6_enable" ] ; then
    prompt '_includeIPv6' 'Do you want to include IPv6 traffic?\n	(i.e., you *must* have a full version if `ip` installed)' "$yn_n" '0' $zo_r
    if [ "$_includeIPv6" -eq 1 ] ; then
        local tip=$(echo `ip -6 neigh show`)
        if [ -z "$tip" ] ; then
            echo "
******************************************************************
*  It appears that your firmware does not include the full version 
*  of the \`ip\` command i.e., \`ip -6 neigh show\` returns nothing
******************************************************************
"
            local t_ip=0
            prompt 't_ip' 'Have you installed the full version of `ip` on your router?' "$yn_n" $t_ip $zo_r
            if [ "$t_ip" -eq 1 ] ; then
               prompt '_path2ip' 'Where is the full version of `ip` installed?' '' '/opt/sbin/ip' ^[a-z0-9\/]*$

                if [ ! -f "$_path2ip" ] ; then
                    updateConfig "_includeIPv6" "0"
                    echo "
          *******************************************************
          *  \`$_path2ip\` does not exist... Setting \`_includeIPv6\`=0
          *******************************************************
"
                fi
            else
                updateConfig "_includeIPv6" "0"
                echo "
          *******************************************************
          *  Resetting \`_includeIPv6\`=0
          *******************************************************
"
            fi
        fi
    fi
fi
prompt '_symlink2data' 'Create symbollic links to the web data directories?' "$yn_y" '1' $zo_r
[ "$_firmware" -eq "2" ] && prompt '_wwwPath' 'Specify the path to the web directories?' "" '/tmp/var/wwwext/' ^[a-z0-9\/]*$
prompt '_organizeData' 'Organize the data files (into directories by year or year-month)?' 'Options: 0->No(*) -or- 1->by year -or- 2->by year & month' '0' $zot_r
prompt '_enableLogging' 'Enable logging (for support & debugging purposes)?' "$yn_y" '1' $zo_r
[ "$_enableLogging" -eq 1 ] && prompt '_log2file' 'Where do you want to send the logging info?' 'Options: 0->screen -or- 1->file(*) -or- 2->both' '1' $zot_r
[ "$_enableLogging" -eq 1 ] && prompt '_loglevel' 'How much detail do you want in the logs?' 'Options: -1->really verbose -or- 0->all -or- 1->most(*) -or- 2->serious only' '1' ^[012]$\|^-1$
[ "$_log2file" -eq 2 ] || [ "$_log2file" -eq 2 ] && prompt '_scrlevel' 'How much detail do you want shown on the screen?' 'Options: -1->really verbose -or- 0->all -or- 1->most(*) -or- 2->serious only' '1' ^[012]$\|^-1$

local canftp=$(busybox | grep -o 'ftpput')
_enable_ftp=0
[ ! -z "$canftp" ] && prompt '_enable_ftp' 'Do you want to mirror a copy of your data files to an external FTP site? \n	NB - *YOU* must setup the FTP site yourself!' "$yn_n" '0' $zo_r
if [ "$_enable_ftp" -eq "1" ] ; then
    prompt '_ftp_site' 'What is the URL for your FTP site?' '' '' ''
    prompt '_ftp_user' 'What is the username for your FTP site?' '' '' ''
    prompt '_ftp_pswd' 'What is the password for your FTP site?' '' '' ''
else
    updateConfig "_enable_ftp" "0"
    prompt '_doDailyBU' 'Enable daily backup of data files?' "$yn_y" '1' $zo_r
    [ "$_doDailyBU" -eq 1 ] && prompt '_tarBUs' 'Compress the backups?' "$yn_y" '1' $zo_r
fi
[ ! -f "$_dnsmasq_conf" ] && echo "  >>> specified path to _dnsmasq_conf ($_dnsmasq_conf) does not exist"
[ ! -f "$_dnsmasq_leases" ] && echo "  >>> specified path to _dnsmasq_leases ($_dnsmasq_leases) does not exist"
if [ "$_firmware" -eq "1" ] ; then
    local etc_init="/etc/init.d/yamon3"
    [ "$_dnsmasq_conf" == "/tmp/dnsmasq.conf" ] && updateConfig "_dnsmasq_conf" "/tmp/etc/dnsmasq.conf"
    [ "$_dnsmasq_leases" == "/tmp/dnsmasq.leases" ] && updateConfig "_dnsmasq_leases" "/tmp/dhcp.leases"
    local t_init=0
    prompt 't_init' 'Create YAMon init script in `/etc/init.d/`?' "$yn_y" '1' $zo_r
    if [ "$t_init" -eq "1" ] ; then
        [ ! -d "/etc/init.d/" ] mkdir -p "/etc/init.d/" # is this even necessary?
        echo "#!/bin/sh /etc/rc.common
START=99
STOP=10
start() {       
    # commands to launch application
    if [ -d "$_lockDir" ]; then
        echo 'Unable to start, found YAMon3-running directory'
        return 1
    fi
    ${d_baseDir}startup.sh 10 &
}                 
stop() {         
    ${d_baseDir}shutdown.sh
    return 0
}
restart() {         
    ${d_baseDir}restart.sh
    return 0
}
boot() {
    start
}" > "$etc_init"
        chmod +x "$etc_init"
    fi
fi
_configFile="${d_baseDir}config.file"
if [ ! -f "$_configFile" ] ; then
	touch "$_configFile"
	echo "
******************************************************************
Created and saved settings in new file: \`$_configFile\`
******************************************************************"
else
	copyfiles "$_configFile" "${d_baseDir}config.old"
	echo "
******************************************************************
Copied previous configuration settings to \`${d_baseDir}config.old\`
and saved new settings to \`$_configFile\`
******************************************************************"
fi
echo "$configStr" > "$_configFile"

su="${d_baseDir}startup.sh"
sd="${d_baseDir}shutdown.sh"
ya="${d_baseDir}yamon${_version}.sh"
h2m="${d_baseDir}h2m.sh"
glc="${d_baseDir}glc.sh"

prompt 't_permissions' "Do you want to set directory permissions for \`${d_baseDir}\`?" "$yn_y" '1' $zo_r
if [ "$t_permissions" -eq "1" ] ; then
	prompt 't_perm' "What permission value do you want to use?" "e.g., 770(*)-> rwxrwx---" '770' ^[0-7][0-7][0-7]$
	chmod "$t_perm" -R "$d_baseDir"
	chmod "$t_perm" "$su"
	chmod "$t_perm" "$sd"
	chmod "$t_perm" "$ya"
	chmod "$t_perm" "$h2m"
	chmod "$t_perm" "$glc"
else
	chmod 700 -R "$d_baseDir"
	chmod 700 "$su"
	chmod 700 "$sd"
	chmod 700 "$ya"
	chmod 700 "$h2m"
	chmod 700 "$glc"
fi

    prompt 't_www' "Do you want to set directory permissions for \`${_wwwPath}\`?" "$yn_y" '1' $zo_r
    [ "$t_www" -eq "1" ] && chmod -R  "$_wwwPath" 
    
t_perm="770"
t_perm_msg="e.g., $t_perm(*)-> rwxrwx---"
local perm_r=^[0-7][0-7][0-7]$
if [ "$_firmware" -eq "1" ] ; then
    t_perm="a+rX"
    t_perm_msg="e.g., $t_perm(*)-> rwxrwx---"
    perm_r=^[0-7+][0-7][0-7]$
fi
prompt 't_www' "Do you want to set directory permissions for \`${_wwwPath}\`?$extra_msg" "$yn_y" '1' $zo_r

if [ "$t_permissions" -eq "1" ] ; then
	prompt 't_perm' "What permission value do you want to use?" "t_perm_msg" "$t_perm" $perm_r
	chmod "$t_perm" -R "$_wwwPath"
else
	chmod 700 -R "$_wwwPath"
fi
startup_delay=''
prompt 'startup_delay' "By default, \`startup.sh\` will delay for 10sec prior to starting \`yamon${_version}.sh\`. Some routers may require extra time." 'Enter the start-up  delay [0-300]' '10' ^[0-9]$\|^[1-9][0-9]$\|^[1-2][0-9][0-9]$\|^300$
if [ "$_firmware" -ne "1" ] ; then
	prompt 't_startup' 'Do you want to create startup and shutdown scripts?' "$yn_y" '1' $zo_r
	if [ "$t_startup" -eq "1" ] ; then
		cnsu=$(nvram get rc_startup)
		if [ -z "$cnsu" ] ; then
			echo "
	nvram-->rc_startup was empty... \`$su\` was added"
			nvram set rc_startup="$su $startup_delay"
		elif [ -z $(echo "$cnsu" | grep 'startup.sh') ] ; then
			echo "
	nvram-->rc_startup was not empty but does not contain the string \`startup.sh\`... 
    \`$su\` was appended"
			nvram set rc_startup="$cnsu
$su $startup_delay"

		else
            echo -e "
	nvram-->rc_startup already contains the string \`startup.sh\`...
    \`$su\` was not added"
		fi
		cnsd=$(nvram get rc_shutdown)
		if [ -z "$cnsd" ] ; then
			echo "
	nvram-->rc_shutdown was empty... \`$sd\` was added"
			nvram set rc_shutdown="$sd"
		elif [ -z $(echo "$cnsd" | grep 'shutdown.sh') ] ; then
			echo "
	nvram-->rc_shutdown was not empty but does not contain the string \`shutdown.sh\`... 
    \`$sd\` was appended"
			nvram set rc_shutdown="$cnsd
$sd"
		else
			echo -e "
	nvram-->rc_shutdown already contains the string \`shutdown.sh\`...
    \`$sd\` was not added"
		fi
		nvram commit
	fi
fi
#to do... create startup/shutdown scripts for openWRT too

prompt 't_launch' 'Do you want to launch YAMon now?' "$yn_y" '1' $zo_r
if [ "$t_launch" -eq "1" ] ; then
	echo "

****************************************************************
	
[Re]starting $su

" 
    ${YAMON}restart.sh $startup_delay
	exit 0
fi

echo "

****************************************************************
	
YAMon$_version is now configured and ready to run.

To launch YAMon, enter \`${YAMON}startup.sh\`.

Send questions to questions@usage-monitoring.com

Thank you for installing YAMon.  You can show your appreciation and support future development by donating at http://usage-monitoring.com/donations.php.
	
Thx!	Al
	
"