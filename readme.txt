Yet Another Monitor (version 3.3.6)
Last updated: Nov 17, 2017

Yet Another Monitor (YAMon) records and reports on the traffic (downloads and uploads) for all of the devices connecting to your router.  The data is aggregated by hour, day and month (within your ISP billing interval) and can be rolled-up into arbitrary groups (e.g., by family member, function, location or by any other logical grouping of devices).  

YAMon runs on routers that have been `flashed` to one of the *WRT firmware variants (e.g., DD-WRT, OpenWRT, LEDE, TurrisOS, AsusWRT, Tomato,X-WRT, etc.) and gives you an unprecedented view of the traffic on your network.  The reports allow you to see 
- which devices used how much bandwidth, when - e.g., did your kids really go to school?  did they shut off their devices at bedtime?  
- who is consuming the most bandwidth on which device(s)
- whether you are at risk of exceeding your data usage cap for your ISP billing interval (allowing you to throttle consumption before you get hit with a large overage fee).  
- which IP addresses each device is connecting to (including geo-location lookups).  You can find out, or at least ask, why your kid's device is connecting to a server in Lithunia or elsewhere.  
- usage history across multiple billing intervals.  
Further, you can optionally include upload/download figures from your ISP to compare totals recorded at your router with theirs.  Other options in the configuration file allow you to define an `bonus data` interval (e.g., some ISPs do not count usage between 2AM and 7AM towards your bandwidth cap), etc.

For a more detail explanation of YAMon's features and benefits, please go to http://usage-monitoring.com.

--------------------------------------
SHORT REQUIREMENTS CHECKLIST FOR YAMon
--------------------------------------
These instructions presume that 
1) you have a router running a supported firmware variant (e.g., DD-WRT, OpenWRT, Turris Omnia, Tomator, X-wrt, AsusWRT, etc.).  See your firmware discussion forums, if you have any questions about installing or configuring the firmware.

2) you have a permanent storage location for YAMon's data files.  This is easiest if you are able to plug a USB drive directly into your router.  If your router does not have a USB port, do not despair as it is possible to mount a shared volume on your network and use that instead - however, you'll have to deviate somewhat from the default installation steps describe below (and this document does not cover those configuration steps).  

   NB - if you are plugging a USB drive into your router, I recommend that it is formatted to the `ext4` file system.  Some users have tried other formatting schemes and have gotten messages about a `read-only file system error`.  I am currently using `ext4` and not experiencing any difficulties... I did have occasional difficulties when I used `ext2`.
   Apparently some odd chipset/firmware combinations do not support `ext4` (the drive either does not mount or mounts with read-only permissions).  See http://usage-monitoring.com/common-problems.php?t=bad-drive
   Make sure that your USB drive has reasonable read/write speeds! See http://usage-monitoring.com/help/?t=usb-size
   Do not use a Fat32 drive... apparently Fat32 does not support symlinks which YAMon uses to minimize the file movements & server loads.

3) you are familiar with the tools necessary to update files and run commands on your router.  Personally, I have Windows-based machines and use `winSCP` for copying/moving files (http://winscp.net) and `Putty` for running commands on the router (http://www.putty.org/).  When I edit the files, I use Notepad++ (http://notepad-plus-plus.org/).  There are a number of other suitable tools but these are the ones that I use and prefer.
 
   NB - see the KNOWN ISSUES section below because a number of text editors can cause problems!

------------------------------------------------
BEFORE UPDATING FROM A PREVIOUS VERSION OF YAMON
------------------------------------------------
***NOTE*** If you are updating from a previous version of YAMon, backup your current config.file (note, I didn't say please... just do it... OK?)
Also, open the reports, go to the Settings tab and click `Export Settings`.  Copy the values from this dialog and paste them into a text file and save them... just in case!

-----------------------------------------
BASIC INSTALLATION STEPS FOR VERSION 3.x
-----------------------------------------

For more detailed instructions, see http://usage-monitoring.com/download.php#sect-2

After downloading and expanding the most recent YAMon install script from http://usage-monitoring.com/download.php:

1. Copy the contents of the installer zip file to a directory on your router (e.g., `/opt`)

2. Make sure that `install.sh` has execute permissions

3. Run `install.sh` (e.g., by launching PuTTY and entering `/opt/install.sh`). This script will download current versions of all of the necessary files and walk you through the process of setting the proper parameters in your config.file, will set necessary permissions, and, optionally, launch the YAMon script.

4. If you did not automatically launch the script in step #3 above, you can do so by entering `/opt/YAMon3/startup.sh` in a PuTTY window.  You stop the script by entering `/opt/YAMon3/shutdown.sh`

---------------------------
CHANGING YOUR CONFIGURATION
---------------------------
Note you can edit `config.file` at any time.  It is not necessary to stop and restart the script when you do this; the script will detect and incorporate your changes on the fly (however, it may take several minutes for the changes to take effect because the script checks to see whether the file has changed every ~3 min).

----------------------------
CONFIGURING YOUR WEB REPORTS
----------------------------

There's not much that you have to do here.  As mentioned above, the script will automatically download and/or create all of the necessary files.

To access the reports, go to http://<router_ip>/<path>/index.html - e.g., http://192.168.1.1/user/index.html  The value of `<path>` will be set when you run install.sh or setup.sh

When you open the reports for the first time, you will get an intro screen that asks you to confirm that settings in the reports are consistent with those you've set in `config.file`.  Change the values as necessary (or accept the defaults) and click the green checkmark to confirm each setting.  Once all of the checkmarks have been cleared, the page will automatically reload and you'll see the reports. (NB - you'll have to repeat this confirmation step if you view the reports from a different device or browser.)

----------
OTHER INFO
----------

The YAMon script creates four primary data files which are typically stored permanently in `/opt/YAMon3/data`. 
1. `users.js` - contains information relating to the device - its IP and mac addresses, its name and the group (or owner) to which it belongs:
    ud_a({"mac":"11:22:33:44:55:66","ip":"192.168.1.1","owner":"Al","name":"iPhone","colour":"","added":"2014-02-10 22:05:03","updated":"2014-03-02 13:33:30"})

Lines will be added to this file as soon as new devices are detected on the network.  
 
    ud_a({"mac":"00:00:XX:XX:XX:XX","ip":"192.168.1.99","owner":"Unknown","name":"New Device","colour":"","added":"2016-02-10 22:05:03","updated":"2016-03-02 13:33:30"})
    
If/when an IP address changes, the updated field will be changed (as well as the IP address).

You can manually edit (using vi or notepad++, etc.) to personalize the information in your reports.  

***NEW *** you must stop the script *before* editing users.js

In particular, you will want to change the following fields:
owner - the category into which the device should be grouped (e.g., family member name, `Visitors`, or any other arbitrary category)
name - a friendly description of the device (e.g., Betty's phone, Printer, Living room Roku, etc.), maybe, the colour fields  The optional colour parameter, colour - if set, it will use the specified colour for that device in all applicable graphs in the Web reports.  The value must be either one of the 140 `named` HTML colours or a valid hexidecimal colour value (see http://www.w3schools.com/html/html_colornames.asp)
For the owner and name fields, apostrophes (but not double quotes) are permitted

*** see `Known Issues` below for issues relating to some text editors

The users file is created in /opt/YAMon3/data.

2. Hourly Usage file
The file name is set to the year, month, date - e.g., `2014-03-26-hourly_data.js` and contains a number of JavaScript variables and a couple of JavaScript function calls.
a) Device usage: Each device will have a row for each hourly interval that it is active on the network - e.g.,
    hu({"mac":"11:22:33:44:55:66","hour":"02","down":42610,"up":57730,"ul_do":42610,"ul_up":57730})
The down & up fields represent the total traffic for that interval in bytes.  The ul_do & ul_up will only appear if you have set `_unlimited_usage=1` in your config.file

b) Router totals: one entry for each hour of the day plus another for the starting value for the day.  The uptime is used to detect whether the router restarted at any point during the interval.
    pnd({"hour":"00","uptime":26832.41,"down":1282731111,"up":75259806})

A new hourly usage file is created automatically at midnight every day and is stored in /opt/YAMon3/data[/year[/month]] (depending on the value of `_organizeData` in config.file).  The file is updated depending on the values of _updatefreq and _publishInterval in config.file.   

NB - You should not have to edit this file... if you have to edit the file for the current day, you must first stop the script *before* making any changes.

3. Monthly Usage file
The file name is set to the year, month, reset_date - e.g., `2014-03-05-mac_data.js` and will contain daily totals for every device that was on your network during that billing interval.

a) Device usage: Each device will have a row for each day that it is active on the network - e.g.,
    dt({"mac":"11:22:33:44:55:66","day":"05","down":95116718,"up":12979815,"ul_do":0,"ul_up":0})

The down & up fields represent the total traffic in bytes.  The ul_do & ul_up will only appear if you have set `_unlimited_usage=1` in your config.file.

b)  Router totals: one entry for each day of the billing interval.  The reboots field will show the number of times the server was rebooted on the given day.  It will not appear if the server was not rebooted.
    dtp({"day":"09","down":3797402062,"up":136921041,"reboots":"1"})
    
This file is updated automatically just after midnight every day.  A new file is created automatically at the beginning of every billing interval (e.g., at midnight on the day before the reset date) as per the value of `_ispBillingDay` and is stored in /opt/YAMon3/data[/year[/month]] (depending on the value of `_organizeData` in config.file).  

NB - You should not have to edit the Monthly Usage file.

4. Live Usage file
This file is created in /tmp/www/data only if _doLiveUpdates is set to `1` in your config.file.  It contains JavaScript functions and variables relating the current devices connecting to the router.

The file is updated as per the value of _updatefreq in your config.file.

NB - do not try to edit this file...

-------------
KNOWN ISSUES:
-------------

1. If you edit any of the configuration files (config.file, users.js, etc.), you *MUST* leave an blank line at the bottom of the file.

2. The Privoxy extension will interfere with data collection by YAMon... it either adds iptables or UPnP rules that intercept traffic usage data before YAMon sees it.  Unfortunately, ATM I do not know of any way to get around this.

3. Also, at least one user has reported that you should not use MSWord or WordPad to edit the files (especially your `config.file` but I expect that the same problems would also occur if the startup and shutdown scripts are edited in the same too)... apparently it adds additional end of line characters that really mess things up when you try to run the script.  This problem also seems to occur if you use the standard text editor on a Mac.

If you edit any of the files on your windows box, please make sure that you're using an editor that does not change the end-of-line characters to windows format `CRLF` characters (WordPad will do this to you and some other editors if they're not configured properly).  If you find that you're getting and error message that the file "startup.sh" was not found, this is likely what has happened... to check, open the file in notepad++ and navigate to View >> Show symbols >> Show end of line. If you see CRLF at the end of each line, that is windows format. In Notepad++, to change EOL back to unix format navigate to Edit >> EOL conversion >> UNIX/OSX format. Your EOL should now show LF. [Thanks to Canadian Geek, bpsmicro and spanman for tracking this down and identifying the root cause.]

4. If you run out of disk space on your USB drive, the script will not run properly (and it doesn't fail gracefully)!  Clear out the log files and/or daily backups to create more space or get a bigger USB drive.

5. If your router experiences a sudden unexpected shut down, one or more data files on your USB drive could be left in a bad state... most commonly, it is your users.js and hourly data files which are corrupted.  See http://www.dd-wrt.com/phpBB2/viewtopic.php?p=968733#968733 for the steps that resurrected things for me.
I have found that formatting your USB drive with the `ext4` file system seems to eliminate this issue.

---------
DONATIONS
---------

Thank you for using YAMon!  You can show your appreciation and support future development by donating... see https://www.paypal.me/YAMon/30.10

THANK YOU ***VERY*** MUCH TO EVERYONE WHO HAS CONTRIBUTED... see http://usage-monitoring.com/donations.php

-------------
IN CONCLUSION
-------------

If you have any difficulties, please let me know and I'll do my best to help figure things out.  Or, post a comment on the DD-WRT forum... there's lots of smart folks there.  Your feedback is appreciated.

Thanks!

Al Caughey
al@caughey.ca

----------
DISCLOSURE
----------
By default, the standard YAMon reports which you are adding to your router contain references JavaScript (JS) and Cascading Style Sheet (CSS) files that are hosted at my domain (http://usage-monitoring.com).  My ISP provides me with visitor traffic reports which that means that I get anonymous usage statistics relating to this content.

A number of users have raised this as a legitimate (yet, IMHO, unfounded) privacy/web tracking concern.  To address this, I  
1. am making sure that everyone is aware that some files are hosted at my domain and that I get usage statistics from my ISP, and 
2. have added an optional parameter to 'config.file' that will copy the files to your router so that you can host the files locally on your router.

Why do I host the JS and CSS files?  
First and foremost because it allows me to make corrections and updates to the reports in a much faster fashion.  I do not have to create a new zip archive for every update and I do not have take as much time to craft update notifications in the DD-WRT forum.  It also means that:
- less space is required on your router to store these files
- you always see the latest/greatest version of the reports, and
- you only have to update your router when there are changes within the bash scripts (which is becoming increasingly infrequent). 

As indicated above, my ISP provides me with anonymous usage information (typical of any web server).  I do get ISP addresses but more often than not, those are internal - e.g., 192.168.1.1, etc.  The server logs do *NOT* give any information about your yamon configuration, the internal workings of your router or the traffic on your network... and quite honestly, if I was really interested in gathering that info, it'd be far more efficient/effective if I hid that functionality in the bash script on your router rather than in a JavaScript file on an external server.  (And I stress that I have *NOT* done that!) 

Please note that I also use other external JavaScript libraries in the reports - in particular, jQuery (for general dynamic functionality) and the Google Visualize libraries (for the graphs and gauges).  Rest assured that at least one of those two organizations has access to far better tracking technology than what I get from my ISP.

I am not trying minimize these concerns... they are legitimate. But please trust me, when I say that I'm not hosting the content because I want to track your usage in any way.

In version 2.0.17, I added an optional feature that will allow you to share all of your setting across all devices that access the YAMon reports.  This is accomplished by setting up a database table at my usage-monitoring.com domain.  When you save your settings, a copy of the the localStorage values on that machine are written to your database.  All users who enable this option have their data saved into separate database table. I have a table that records which IP address created which table but otherwise do not capture any personal information.  If you object to this, do not enable this option.

In version 2.0.18, I added an optional feature that will send alerts if new devices are added to your users.js file (or if your iptables settings are messed up).  Rather than wrestling with configuring settings for everyone's mail options, the alerts are sent via the mail server on usage-monitoring.com.  To prevent abuse of this mail server, I keep a log of when alerts were sent, from which IP address and to whom they were sent.  If you object to this, do not enable this option.

In version 2.2, I added a feature in the Current Connections table on the Live Usage tab that performs a geo-location look-up for the IP addresses in that table i.e., it returns the organization name and city & country for the IP addresses.  Those look-ups are completed using functionality at usage-monitoring.com.  There is also an option that will anonymously share the IP address information across users (so that you do not have to look up addresses I've already checked).  If you object to this, do not click that link!

Thank you for your understanding.