#!/bin/sh
#
##############################################################################
#
# Fetch screensaver image from a configurable URL.

cd "$(dirname "$0")" || exit 1

if [ -e "config.sh" ]; then
	# shellcheck disable=SC1091
	. ./config.sh
else
	TMPFILE=/tmp/tmp.onlinescreensaver.png
fi

if [ -e "utils.sh" ]; then
	# shellcheck disable=SC1091
	. ./utils.sh
else
	echo "Could not find utils.sh in $(pwd)"
	exit 1
fi

if [ -z "${IMAGE_URI}" ]; then
	logger "No image URL has been set. Please edit config.sh."
	exit 1
fi

WIFI_STATUS=$(lipc-get-prop com.lab126.cmd wirelessEnable)
logger "Initial WiFi status: ${WIFI_STATUS}"

if [ 0 -eq "${WIFI_STATUS}" ]; then
	logger "WiFi is off, turning it on now"
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	DISABLE_WIFI=1

	logger "Waiting 10 seconds for WiFi to initialize..."
	sleep 10
else
	logger "WiFi was already enabled"
fi

WIFI_CONNECTION=$(lipc-get-prop com.lab126.wifid cmState)
logger "WiFi connection state: ${WIFI_CONNECTION}"

TIMER=${NETWORK_TIMEOUT}
CONNECTED=0
PING_ATTEMPTS=0

logger "Starting network connectivity test with ${NETWORK_TIMEOUT} second timeout"

while [ 0 -eq "${CONNECTED}" ]; do
	PING_ATTEMPTS=$((PING_ATTEMPTS + 1))

	if /bin/ping -c 1 -w 2 "${TEST_DOMAIN}" > /dev/null 2>&1; then
		CONNECTED=1
		logger "Connected after ${PING_ATTEMPTS} ping attempts"
	else
		if [ $((PING_ATTEMPTS % 10)) -eq 0 ]; then
			PING_RESULT=$(/bin/ping -c 1 -w 2 "${TEST_DOMAIN}" 2>&1)
			logger "Ping attempt ${PING_ATTEMPTS} to ${TEST_DOMAIN} failed: ${PING_RESULT}"

			CURRENT_WIFI_STATE=$(lipc-get-prop com.lab126.wifid cmState)
			logger "WiFi state during ping failure: ${CURRENT_WIFI_STATE}"
		fi

		TIMER=$((TIMER - 1))
		if [ 0 -eq "${TIMER}" ]; then
			logger "No internet after ${NETWORK_TIMEOUT}s and ${PING_ATTEMPTS} pings, aborting."
			break
		else
			sleep 1
		fi
	fi
done

if [ 1 -eq "${CONNECTED}" ]; then
	logger "Network up, downloading image"

	FETCH_URI="${IMAGE_URI}"
	if [ "${REQUEST_RESIZE:-0}" -eq 1 ] && [ -n "${W}" ] && [ -n "${H}" ]; then
		case "${FETCH_URI}" in
			*"?"*) FETCH_URI="${FETCH_URI}&w=${W}&h=${H}" ;;
			*)     FETCH_URI="${FETCH_URI}?w=${W}&h=${H}" ;;
		esac
	fi

	WGET_OUTPUT=$(wget --no-check-certificate -q "${FETCH_URI}" -O "${TMPFILE}" 2>&1)
	WGET_EXIT_CODE=$?

	if [ "${WGET_EXIT_CODE}" -eq 0 ]; then
		mv "${TMPFILE}" "${SCREENSAVERFILE}"
		logger "Screensaver image updated from ${IMAGE_URI}"

		DEVICE_STATUS=$(lipc-get-prop com.lab126.powerd status)
		case "${DEVICE_STATUS}" in
			*"Ready"*|*"Screen Saver"*)
				logger "Refreshing screen"
				eips -f -g "${SCREENSAVERFILE}"
				;;
		esac
	else
		logger "wget failed with exit code ${WGET_EXIT_CODE} for ${IMAGE_URI}"

		if [ -n "${WGET_OUTPUT}" ]; then
			logger "wget error: ${WGET_OUTPUT}"
		fi

		if [ -f "${TMPFILE}" ]; then
			rm -f "${TMPFILE}"
			logger "Removed incomplete temporary file ${TMPFILE}"
		fi

		if [ "${DONOTRETRY:-0}" -eq 1 ]; then
			touch "${SCREENSAVERFILE}"
		fi
	fi
else
	logger "No network connection, skipping image download"
fi

if [ "${DISABLE_WIFI:-0}" -eq 1 ]; then
	logger "Disabling WiFi"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi
