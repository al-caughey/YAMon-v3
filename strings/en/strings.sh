los="**********************************************************"
loh="  ##########################################################

Continuing set up...
"
err="***                    *** ERROR ***"
wrn="  #####################* W A R N I N G *#####################"
blank="***"
bl_a="  ##"

_s_title="
$los
$los
 ___     ___   ___       ____   ____
 \\\\\\\\   ////  //|\\\\     |||\\\\\\ ///|||   _____    _  ___
  \\\\\\\\ ////  ///A\\\\\\    ||||\\\|//||||  ///O\\\\\\  ||N///\\\\
   \\\\\\|///  //// \\\\\\\\   |||| \\M/ |||| ///   \\\\\\ |||//|\\\\\\
    \\\Y//  ////   \\\\\\\  ||||  V  |||| |||   ||| |||   |||
    ////  //////|\\\\\\\\\\\\ ||||     |||| \\\\\\   /// |||   |||
   ////  ////       \\\\\\\\||||     ||||  \\\\\\|///  |||   |||

                  Yet Another Monitor
            Copyright (c) 2013-present Al Caughey
                  All rights reserved.
               http://usage-monitoring.com

    YAMon Version:: $_version

$los"

_s_noconfig="
$los
$err
***  \`config.file\` does not exist!!!
***  Please install.sh again to ensure that this file is created properly.
$los
"

_s_cannotgettime="
$los
$err
***  Cannot get the date/time set properly?!?
***  Please check your date & time settings in the DD-WRT GUI
$los
"

_s_tostop="
To stop the script:
 * run \`shutdown.sh\` [*RECOMMENDED*]
      e.g., \`${_baseDir}shutdown.sh\`
 * or delete the \`$_lockDir\` directory
      e.g., \`rmdir $_lockDir\`"


_s_running="
$los
$err
***  Unable to start...
***  An instance of \`yamon$_version.sh\` is already running!!!
***  You must stop that instance before starting a new one
$los
$_s_tostop
"

_s_notrunning="
$los
***  No need to stop... \`yamon$_version.sh\` is not running!
***  (The lock directory does not exist)
$los
"

_s_stopping="
$los
$blank
***  Please wait for the message indicating that the script
***  has stopped... this may take up to $_updatefreq seconds
$blank
$los
"

_s_stopped="
$los
***  As requested, \`yamon$_version.sh\` has been stopped.
$los
"

_s_started="
$los
***  \`yamon$_version.sh\` has been started
$los
$_s_tostop"