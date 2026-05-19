#!/bin/sh
##############################################################################
# Battery-efficient utility functions for Kindle scheduler
##############################################################################

DEFAULT_LOG_FLUSH_SIZE=32768

##############################################################################
# Checks if userstore (FAT partition) is safe to write to.
# Returns 1 (false) during USB mass storage mode.

is_userstore_available () {
	_AVAILABLE=$(lipc-get-prop com.lab126.volumd userstoreIsAvailable 2>/dev/null)
	[ "${_AVAILABLE}" = "1" ]
}

##############################################################################
# Flushes the RAM log buffer to the FAT partition when safe.
# Pass "force" to bypass the LOG_FLUSH_SIZE threshold.

flush_log_buffer () {
	_TEMP_LOG="/tmp/onlinescreensaver.log"
	_FORCE="${1}"

	if [ "1" != "${LOGGING}" ] || [ -z "${LOGFILE}" ]; then
		return
	fi
	case "${LOGFILE}" in
		stdout|/dev/stdout|/dev/stderr) return ;;
	esac
	if [ ! -f "${_TEMP_LOG}" ]; then
		return
	fi
	if ! is_userstore_available; then
		return
	fi

	if [ "${_FORCE}" != "force" ]; then
		_LOG_SIZE=$(stat -c%s "${_TEMP_LOG}" 2>/dev/null || echo "0")
		if [ "${_LOG_SIZE}" -lt "${LOG_FLUSH_SIZE:-${DEFAULT_LOG_FLUSH_SIZE}}" ]; then
			return
		fi
	fi

	mkdir -p "$(dirname "${LOGFILE}")" 2>/dev/null
	cat "${_TEMP_LOG}" >> "${LOGFILE}" 2>/dev/null && rm -f "${_TEMP_LOG}" 2>/dev/null
}

##############################################################################
# Logs a message. File destinations buffer to RAM and flush to FAT when safe.

logger () {
	MSG=${1}

	# do nothing if logging is not enabled
	if [ "1" != "${LOGGING}" ]; then
		return
	fi

	# if no logfile is specified, set a default
	if [ -z "${LOGFILE}" ]; then
		LOGFILE=stdout
	fi

	case "${LOGFILE}" in
		stdout|/dev/stdout|/dev/stderr)
			echo "$(date): ${LOG_TAG:+${LOG_TAG}: }${MSG}" >> "${LOGFILE}"
			;;
		*)
			echo "$(date): ${LOG_TAG:+${LOG_TAG}: }${MSG}" >> "/tmp/onlinescreensaver.log"
			flush_log_buffer
			;;
	esac
}

##############################################################################
# Waits for WiFi to reach CONNECTED state, polling up to 4 times.
# $1 - log message to print before waiting
# Sets globals: WIFI_TRIES, WIFI_STATE

wait_for_wifi () {
	logger "$1"
	sleep 3
	WIFI_TRIES=4
	while [ "${WIFI_TRIES}" -gt 0 ]; do
		WIFI_STATE=$(lipc-get-prop com.lab126.wifid cmState)
		logger "WiFi state: ${WIFI_STATE}"
		if [ "${WIFI_STATE}" = "CONNECTED" ]; then
			break
		fi
		WIFI_TRIES=$((WIFI_TRIES - 1))
		# Skip trailing sleep on last iteration to avoid unnecessary delay
		if [ "${WIFI_TRIES}" -gt 0 ]; then
			sleep 2
		fi
	done
	if [ "${WIFI_TRIES}" -eq 0 ]; then
		logger "WiFi did not connect after retries"
	fi
}

##############################################################################
# Retrieves the current time in seconds

currentTime () {
	date +%s
}

##############################################################################
# Tells powerd to wake the device in WAKEUP_DELAY seconds via rtcWakeup.
# powerd only accepts this in readyToSuspend state; other states return
# lipcPropErrInvalidState (logged but harmless).
# arguments: $1 - time in seconds from now, $2 - reason label for logging

set_rtc_wakeup () {
	WAKEUP_DELAY=${1}
	WAKEUP_REASON=${2:-suspend}
	if [ "${WAKEUP_DELAY}" -le 0 ]; then
		logger "RTC wakeup (${WAKEUP_REASON}): skipped (already past)"
		return 0
	fi
	LIPC_RESULT=$(lipc-set-prop -i com.lab126.powerd rtcWakeup "${WAKEUP_DELAY}" 2>&1); LIPC_RC=$?
	if [ "${LIPC_RC}" -eq 0 ]; then
		logger "RTC wakeup (${WAKEUP_REASON}): ${WAKEUP_DELAY}s"
	else
		logger "RTC wakeup (${WAKEUP_REASON}): rejected (${LIPC_RESULT})"
	fi
	return "${LIPC_RC}"
}

##############################################################################
# Battery-efficient wait function that allows proper suspension
# arguments: $1 - time in seconds from now

wait_for_suspend () {
	WAIT_SECONDS=${1}
	logger "Starting battery-efficient wait for ${WAIT_SECONDS} seconds"

	_NOW=$(currentTime)
	ENDTIME=$(( _NOW + WAIT_SECONDS ))

	# Event loop: wait for powerd state transitions until ENDTIME.
	#   readyToSuspend        => set RTC alarm so device wakes for next update
	#   wakeupFromSuspend     => arm RTC preemptively (best-effort, powerd may
	#                            reject outside readyToSuspend), then re-enter
	#                            loop to wait the remaining time
	#   timeout (no event)    => REMAINING <= 0 at top of loop, exit
	while true; do
		_NOW=$(currentTime)
		REMAINING=$(( ENDTIME - _NOW ))
		if [ "${REMAINING}" -le 0 ]; then
			break
		fi

		EVENT=$(lipc-wait-event -s "${REMAINING}" com.lab126.powerd readyToSuspend,wakeupFromSuspend,resuming 2>/dev/null)
		logger "Received event: ${EVENT:-timeout}"

		case "${EVENT}" in
			readyToSuspend*)
				REMAINING=$(( ENDTIME - $(currentTime) ))
				set_rtc_wakeup "${REMAINING}" "suspend"
				;;
			wakeupFromSuspend*|resuming*)
				REMAINING=$(( ENDTIME - $(currentTime) ))
				set_rtc_wakeup "${REMAINING}" "preemptive"
				;;
		esac
	done

	logger "Wait completed, device should be awake"
}

##############################################################################
# Clean RTC wakeup function for device shutdown/cleanup
clear_rtc_wakeup () {
	logger "Clearing RTC wakeup alarm"
	echo 0 > "/sys/class/rtc/rtc${RTC}/wakealarm" 2>/dev/null
}


##############################################################################
# Cleanup function for graceful shutdown
cleanup_and_exit () {
	logger "Performing cleanup before exit"
	flush_log_buffer force
	clear_rtc_wakeup
	exit 0
}

trap cleanup_and_exit TERM INT QUIT
