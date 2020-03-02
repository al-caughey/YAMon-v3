#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  stop and then restart the main YAMon script
#
##########################################################################

_baseDir=`dirname $0`

delay=$1
[ -z $delay ] && delay=10

logger "YAMON:" "Restarting"
sleep $delay
${_baseDir}/shutdown.sh

${_baseDir}/startup.sh $delay &