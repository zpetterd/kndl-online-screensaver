#!/bin/sh

cd "$(dirname "$0")" || exit 1

if [ -e "config.sh" ]; then
	# shellcheck disable=SC1091
	. ./config.sh
fi

if [ -e "utils.sh" ]; then
	# shellcheck disable=SC1091
	. ./utils.sh
else
	echo "Could not find utils.sh in $(pwd)"
	exit 1
fi

logger "Disabling online screensaver auto-update"

stop onlinescreensaver || true

mntroot rw
rm /etc/upstart/onlinescreensaver.conf
mntroot ro
