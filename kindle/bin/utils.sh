#!/bin/sh
##############################################################################
# Battery-efficient utility functions for Kindle scheduler
##############################################################################

##############################################################################
# Checks if userstore (FAT partition) is safe to write to.
# Returns 1 (false) during USB mass storage mode.

is_userstore_available () {
	_AVAILABLE=$(lipc-get-prop com.lab126.volumd userstoreIsAvailable 2>/dev/null)
	[ "${_AVAILABLE}" = "1" ]
}

##############################################################################
# Flushes the RAM log buffer to the FAT partition when safe.
# Pass "force" to bypass the 32KB size threshold.

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
		if [ "${_LOG_SIZE}" -lt 32768 ]; then
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
# Retrieves the current time in seconds

currentTime () {
	date +%s
}

##############################################################################
# Tells powerd to wake the device in WAKEUP_DELAY seconds via rtcWakeup.
# Must be called from a readyToSuspend handler — powerd rejects it in
# any other state with lipcPropErrInvalidState.
# arguments: $1 - time in seconds from now

set_rtc_wakeup () {
	WAKEUP_DELAY=${1}
	LIPC_RESULT=$(lipc-set-prop -i com.lab126.powerd rtcWakeup "${WAKEUP_DELAY}" 2>&1); LIPC_RC=$?
	logger "lipc-set-prop rtcWakeup: rc=${LIPC_RC} out=${LIPC_RESULT:-ok}"
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

	# powerd only accepts rtcWakeup in readyToSuspend state — calling it
	# earlier (e.g. Active) fails with lipcPropErrInvalidState. Wait for
	# that event, set the alarm in that window, then break on resume.
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
				logger "Device ready to suspend, setting RTC wakeup for ${REMAINING}s"
				set_rtc_wakeup "${REMAINING}"
				;;
			wakeupFromSuspend*|resuming*)
				logger "Device resumed, finishing wait"
				break
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
