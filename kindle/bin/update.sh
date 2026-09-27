#!/bin/sh
#
##############################################################################
#
# Fetch screensaver image from a configurable URL.

# shellcheck disable=SC2034
LOG_TAG="update"

SCRIPT_DIR=$(dirname "$0")
cd "${SCRIPT_DIR}" || exit 1

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
	echo "Could not find utils.sh in ${SCRIPT_DIR}"
	exit 1
fi

# shellcheck disable=SC2002
MOUNT_OPTS=$(cat /proc/mounts 2>/dev/null | grep ' /mnt/us ' || true)
logger "Mount options: ${MOUNT_OPTS}"

if [ -z "${IMAGE_URI}" ]; then
	logger "No image URL has been set. Please edit config.sh."
	exit 1
fi

WIFI_STATUS=$(lipc-get-prop com.lab126.cmd wirelessEnable)
logger "Initial WiFi status: ${WIFI_STATUS}"

if [ 0 -eq "${WIFI_STATUS}" ]; then
	DISABLE_WIFI=1
fi

WIFI_STATE=$(lipc-get-prop com.lab126.wifid cmState)
if [ "${WIFI_STATE}" != "CONNECTED" ]; then
	logger "WiFi not connected (state: ${WIFI_STATE}), cycling"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
	sleep 2
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	wait_for_wifi "Waiting for WiFi to connect..."
else
	logger "WiFi already connected"
fi

WIFI_CONNECTION=$(lipc-get-prop com.lab126.wifid cmState)
logger "WiFi connection state: ${WIFI_CONNECTION}"

TIMER=${NETWORK_TIMEOUT}
CONNECTED=0
PING_ATTEMPTS=0

logger "Starting network connectivity test with ${NETWORK_TIMEOUT} second timeout"

while [ 0 -eq "${CONNECTED}" ]; do
	PING_ATTEMPTS=$((PING_ATTEMPTS + 1))

	if ping -c 1 -w 2 "${TEST_DOMAIN}" > /dev/null 2>&1; then
		CONNECTED=1
		logger "Connected after ${PING_ATTEMPTS} ping attempts"
	else
		if [ $((PING_ATTEMPTS % 10)) -eq 0 ]; then
			PING_RESULT=$(ping -c 1 -w 2 "${TEST_DOMAIN}" 2>&1)
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

	# Report battery state so the server can expose it as sensor data
	BATTERY_LEVEL=$(gasgauge-info -s 2>/dev/null)
	IS_CHARGING=$(lipc-get-prop com.lab126.powerd isCharging)
	if [ -n "${BATTERY_LEVEL}" ]; then
		case "${FETCH_URI}" in
			*"?"*) FETCH_URI="${FETCH_URI}&batteryLevel=${BATTERY_LEVEL}&isCharging=${IS_CHARGING}" ;;
			*)     FETCH_URI="${FETCH_URI}?batteryLevel=${BATTERY_LEVEL}&isCharging=${IS_CHARGING}" ;;
		esac
	fi

	ERROR_FILE="/tmp/wget_error.tmp"
	wget -q -O "${TMPFILE}" "${FETCH_URI}" 2>"${ERROR_FILE}"
	WGET_EXIT_CODE=$?

	if [ "${WGET_EXIT_CODE}" -eq 0 ]; then
		rm -f "${ERROR_FILE}"
		logger "Screensaver image updated from ${IMAGE_URI}"

		DEVICE_STATUS=$(lipc-get-prop com.lab126.powerd status)
		logger "Device status before refresh: ${DEVICE_STATUS}"
		case "${DEVICE_STATUS}" in
			*"Active"*)
				logger "Device active, skipping screen refresh"
				;;
			*)
				# Draw directly from tmpfs to the framebuffer. No writes to
				# the FAT32 partition — repeated writes there were corrupting
				# the FAT cluster chain and breaking the extension directory.
				logger "Refreshing screen"
				EIPS_OUTPUT=$(eips -f -g "${TMPFILE}" 2>&1)
				EIPS_EXIT=$?
				if [ "${EIPS_EXIT}" -ne 0 ] || [ -n "${EIPS_OUTPUT}" ]; then
					logger "eips exit=${EIPS_EXIT} output=${EIPS_OUTPUT}"
				fi
				;;
		esac

		if [ "${WRITE_SCREENSAVER:-0}" -eq 1 ] && is_userstore_available; then
			# Overwrite in place so the FAT cluster chain stays unchanged.
			# Avoids the truncate+realloc that cp/mv would do.
			dd if="${TMPFILE}" of="${SCREENSAVERFILE}" conv=notrunc 2>/dev/null
			sync
		fi
		rm -f "${TMPFILE}"
	else
		WGET_OUTPUT=$(cat "${ERROR_FILE}" 2>/dev/null)
		rm -f "${ERROR_FILE}"
		logger "wget failed with exit code ${WGET_EXIT_CODE} for ${IMAGE_URI}"

		if [ -n "${WGET_OUTPUT}" ]; then
			logger "wget error: ${WGET_OUTPUT}"
		fi

		if [ -f "${TMPFILE}" ]; then
			rm -f "${TMPFILE}"
			logger "Removed incomplete temporary file ${TMPFILE}"
		fi

		if [ "${DONOTRETRY:-0}" -eq 1 ]; then
			touch "${TMPFILE}"
		fi
	fi
else
	logger "No network connection, skipping image download"
fi

if [ "${DISABLE_WIFI:-0}" -eq 1 ]; then
	# Skip the WiFi kill while charging — radio draw is free on the charger.
	# isCharging returns 0/1; on failure the var is empty and we fall through
	# to the old behaviour (WiFi off).
	IS_CHARGING=$(lipc-get-prop com.lab126.powerd isCharging 2>/dev/null)
	if [ "${IS_CHARGING}" = "1" ]; then
		logger "Charging, keeping WiFi on"
	else
		logger "Disabling WiFi"
		lipc-set-prop com.lab126.cmd wirelessEnable 0
	fi
fi
