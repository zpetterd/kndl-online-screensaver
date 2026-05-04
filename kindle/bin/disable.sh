#!/bin/sh

SCRIPT_DIR=$(dirname "$0")
cd "${SCRIPT_DIR}" || exit 1

if [ -e "config.sh" ]; then
	# shellcheck disable=SC1091
	. ./config.sh
fi

if [ -e "utils.sh" ]; then
	# shellcheck disable=SC1091
	. ./utils.sh
else
	echo "Could not find utils.sh in ${SCRIPT_DIR}"
	exit 1
fi

logger "Disabling online screensaver auto-update"

stop onlinescreensaver || true

echo 0 > "/sys/class/rtc/rtc${RTC}/wakealarm" 2>/dev/null

mntroot rw
rm /etc/upstart/onlinescreensaver.conf
mntroot ro
