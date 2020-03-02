##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# default parameters - these values may be updated in readConfig()
#
# History
# 3.2.2 - moved _version and _file_version to versions.sh
# 3.3.1 - changed YAMON_IP4, YAMON_IP6, d_configWWW
#       - added d_use_nf_conntrack
#       - removed unused d_lan_iface_only, d_enable_db
##########################################################################

_has_nvram=0
_has_uci=0
_canClear=$(which clear)

[ ! -z "$YAMON" ] && d_baseDir="${YAMON%/}"
[ -z "$d_baseDir" ] && d_baseDir=$(cd "$(dirname "$0")" && pwd)
[ ! -z $(which nvram) ] && _has_nvram=1
[ ! -z $(which uci) ] && _has_uci=1

_lockDir="/tmp/YAMon$_file_version-running"

YAMON_IP4='YAMON33v4'
YAMON_IP6='YAMON33v6'

_PRIVATE_IP4_BLOCKS='10.0.0.0/8,172.16.0.0/12,192.168.0.0/16'
_PRIVATE_IP6_BLOCKS='fc00::/7'

#global defaults
d_firmware=0
d_updatefreq=30
d_publishInterval=4
_lang='en'
d_path2strings="$d_baseDir/strings/$_lang/"
d_setupWebDir="www/"
d_setupWebIndex="yamon$_file_version.html"
d_dataDir="data/"
d_logDir="logs/"
d_wwwPath="/tmp/www/"
d_wwwURL="/user"
d_wwwJS="js/"
d_wwwCSS="css/"
d_wwwImages='images/'
d_wwwData="data"
d_dowwwBU=0
d_wwwBU="wwwBU/"
d_usersFileName="users.js"
d_hourlyFileName="hourly_data.js"
d_usageFileName="mac_data.js"
d_configWWW="config$_file_version.js"
d_symlink2data=1
d_enableLogging=1
d_log2file=1
d_loglevel=0
d_scrlevel=0
d_ispBillingDay=5
d_doDailyBU=1
d_tarBUs=0
d_doLiveUpdates=1
d_doCurrConnections=1
d_liveFileName="live_data3.js"
d_dailyBUPath="daily-bu/"
d_unlimited_usage=0
d_unlimited_start="02:00"
d_unlimited_end="08:00"
d_settings_pswd=''
d_dnsmasq_conf="/tmp/dnsmasq.conf"
d_dnsmasq_leases="/tmp/dnsmasq.leases"
d_do_separator=""
d_includeBridge=0
d_bridgeMAC='XX:XX:XX:XX:XX:XX'
d_bridgeIP='###.###.###.###'
d_defaultOwner='Unknown'
d_defaultDeviceName='New Device'
d_includeIPv6=0
d_doLocalFiles=0
d_dbkey=''
d_ignoreGateway=0
d_gatewayMAC=''
d_sendAlerts=0
d_organizeData=2
d_allowMultipleIPsperMAC=0
d_includeIPv6=0
d_path2ip='ip'
d_enable_ftp=0
d_ftp_site=''
d_ftp_user=''
d_ftp_pswd=''
d_ftp_dir=''
d_useTMangle=0
d_use_nf_conntrack=1
d_path2MSMTP=/opt/usr/bin/msmtp
d_MSMTP_CONFIG=/opt/scripts/msmtprc

loadconfig()
{
	#if the parameters are missing then set them to the defaults
	local dirty=''
	local mfl=''
	local p_list=$(cat "${d_baseDir}/default_config.file" | grep -o "^_[^=]\{1,\}")

	IFS=$'\n'
	for line in $(echo "$p_list")
	do
		eval nv=\"\$$line\"
		[ ! -z "$nv" ] && continue
		local dvn="d$line"
		eval dv=\"\$$dvn\"
		[ -z "$dv" ] && continue
		dirty="true"
		eval $line=\"\$$dvn\"
		mfl="$mfl
	* $line ($dv)"
	done
	
	if [ "$_enableLogging" -eq "0" ] ; then
		send2log="send2log_"$_enableLogging
	else
		send2log="send2log_"$_enableLogging"_"$_log2file
	fi

	if [ "$_sendAlerts" -eq "0" ] ; then
		sendAlert="sendAlert_$_sendAlerts" 
	elif [ -z "$_sendAlertTo" ] ; then
		sendAlert="sendAlert_0" 
		$send2log "_sendAlertTo cannot be null if '_sendAlerts' is not zero" 2
	else
		sendAlert="sendAlert_1"
	fi
	[ ! -z "$dirty" ] && echo "
###########################################################
NB - One or more parameters were missing in your config.file!$mfl
The missing entries have been assigned the defaults from \`default_config.file\`.

See \`default_config.file\` for more info about these values and/or run setup.sh
again to update your config.file.
###########################################################
"
	if [ "$_unlimited_usage" -eq "1" ] ; then
		_ul_start=$(date -d "$_unlimited_start" +%s);
		_ul_end=$(date -d "$_unlimited_end" +%s);
		[ "$_ul_end" -lt "$_ul_start" ] && _ul_start=$((_ul_start - 86400))
		#$send2log "	  _unlimited_usage-->$_unlimited_usage ($_unlimited_start->$_unlimited_end / $_ul_start->$_ul_end)" 1
	fi

	local ipv6_enable=''
	if [ "$_has_nvram" -eq 1 ] ; then
		ipv6_enable=$(nvram get ipv6_enable)
	fi

	[ "$_firmware" -eq '0' ] && [ "$_includeIPv6" -eq '1' ] && [ -z "$ipv6_enable" ] && _includeIPv6=0 && echo "Setting \`_includeIPv6=0\` because ipv6_enable!=1 in nvram"

	_tMangleOption=''
	[ "$_useTMangle" -eq "1" ] && _tMangleOption='-t mangle'
}

[ -z "$YAMON" ] && loadconfig