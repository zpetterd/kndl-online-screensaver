#!/bin/sh
# shellcheck disable=SC2034
#############################################################################
### KNDL-ONLINE-SCREENSAVER CONFIGURATION SETTINGS
#############################################################################

# Interval in MINUTES in which to update the screensaver by default. This
# setting will only be used if no schedule (see below) fits. Note that if the
# update fails, the script is not updating again until INTERVAL minutes have
# passed again. So chose a good compromise between updating often (to make
# sure you always have the latest image) and rarely (to not waste battery).
DEFAULTINTERVAL=60

# Schedule for updating the screensaver. Use checkschedule.sh to check whether
# the format is correctly understood.
#
# The format is a space separated list of settings for different times of day:
#       SCHEDULE="setting1 setting2 setting3 etc"
# where each setting is of the format
#       STARTHOUR:STARTMINUTE-ENDHOUR:ENDMINUTE=INTERVAL
# where
#       STARTHOUR:STARTMINUTE is the time this setting starts taking effect
#       ENDHOUR:ENDMINUTE is the time this setting stops being active
#       INTERVAL is the interval in MINUTES in which to update the screensaver
#
# Time values must be in 24 hour format and not wrap over midnight.
# EXAMPLE: "00:00-06:00=480 06:00-18:00=15 18:00-24:00=30"
#          -> Between midnight and 6am, update every 4 hours
#          -> Between 6am and 6pm (18 o'clock), update every 15 minutes
#          -> Between 6pm and midnight, update every 30 minutes
#
# Use the checkschedule.sh script to verify that the setting is correct and
# which would be the active interval.
SCHEDULE="00:00-07:00=90 07:00-21:00=10 21:00-24:00=20"

# URL of screensaver image. This really must be in the EXACT resolution of
# your Kindle's screen (e.g. 600x800 or 758x1024) and really must be PNG.
IMAGE_URI="http://enter.the.domain/here/and/the/path/to/the/image.png"

# Auto-detect device model, screen resolution, and screensaver filename.
# These can be overridden below if auto-detection fails.
if [ -e "device.sh" ]; then
	# shellcheck disable=SC1091
	. ./device.sh
	get_device_info
fi

# Also persist the image to SCREENSAVERFILE on the FAT32 partition so it
# survives reboots and is shown immediately when entering screensaver mode.
# Disabled by default
WRITE_SCREENSAVER=0

# folder that holds the screensavers
SCREENSAVERFOLDER=/mnt/us/linkss/screensavers

# Screensaver filename — auto-detected from device model, override if needed.
SCREENSAVERFILE=${SCREENSAVERFOLDER}/${SCREENSAVER_BASENAME:-bg_ss00.png}

# Whether to append ?w=WIDTH&h=HEIGHT query parameters to IMAGE_URI so the
# server can resize the image to match this device. Only useful when using
# a server that supports the resize endpoint. (1=yes, 0=no)
REQUEST_RESIZE=0

# whether to disable WiFi after the script has finished (if WiFi was off
# when the script started, it will always turn it off)
DISABLE_WIFI=0

# Domain to ping to test network connectivity. Default should work, but in
# case some firewall blocks access, try a popular local website.
TEST_DOMAIN="8.8.8.8"

# How long (in seconds) to wait for an internet connection to be established
# (if you experience frequent timeouts when waking up from sleep, try to
# increase this value)
NETWORK_TIMEOUT=58



#############################################################################
# Advanced
#############################################################################

# Whether to create log output (1) or not (0).
LOGGING=0

# Where to log to - either /dev/stderr for console output, or an absolute
# file path (beware that this may grow large over time!)
LOGFILE=/dev/stderr
#LOGFILE=/mnt/us/extensions/onlinescreensaver/log/onlinescreensaver.log

# the real-time clock to use (0, 1 or 2)
RTC=0

# the temporary file to download the screensaver image to
TMPFILE=/tmp/tmp.onlinescreensaver.png
