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

if [ -e /etc/upstart ]; then
	logger "Enabling online screensaver auto-update"

	mntroot rw
	cp onlinescreensaver.conf /etc/upstart/
	mntroot ro

	start onlinescreensaver
else
	logger "Upstart folder not found, device too old"
fi
