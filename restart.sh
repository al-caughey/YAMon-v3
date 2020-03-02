#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-2016 Al Caughey
# All rights reserved.
#
#  stop and then restart the main YAMon script
#
##########################################################################

_baseDir=`dirname $0`

delay=$1

${_baseDir}/shutdown.sh
${_baseDir}/startup.sh $delay &