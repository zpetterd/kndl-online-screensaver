#!/usr/bin/env bats

load helpers/setup

setup() {
	stub_kindle_commands

	WORK_DIR="$(mktemp -d)"
	cp "${BATS_TEST_DIRNAME}/../kindle/bin/utils.sh" "${WORK_DIR}/"

	LOGGING=0
	LOGFILE=/dev/stderr
	RTC=0

	rm -f /tmp/onlinescreensaver.log

	cd "${WORK_DIR}" || return 1
	# shellcheck disable=SC1091
	. ./utils.sh
}

teardown() {
	rm -f /tmp/onlinescreensaver.log
	rm -rf "${WORK_DIR}"
}

@test "logger does nothing when LOGGING=0" {
	LOGGING=0
	LOGFILE="${WORK_DIR}/test.log"
	logger "should not appear"
	[ ! -f "${WORK_DIR}/test.log" ]
}

@test "logger writes to file when LOGGING=1" {
	LOGGING=1
	LOGFILE="${WORK_DIR}/test.log"
	logger "hello world"
	flush_log_buffer force
	[ -f "${WORK_DIR}/test.log" ]
	grep -q "hello world" "${WORK_DIR}/test.log"
}

@test "logger output contains timestamp" {
	LOGGING=1
	LOGFILE="${WORK_DIR}/test.log"
	logger "test message"
	flush_log_buffer force
	# date output contains a colon (HH:MM:SS)
	grep -q ":" "${WORK_DIR}/test.log"
}

@test "currentTime returns a Unix timestamp" {
	RESULT=$(currentTime)
	# Should be a number greater than year 2020 epoch
	[ "${RESULT}" -gt 1577836800 ]
}

@test "currentTime returns increasing values" {
	T1=$(currentTime)
	T2=$(currentTime)
	[ "${T2}" -ge "${T1}" ]
}

@test "wait_for_suspend exits after time elapses and calls lipc-wait-event" {
	CALL_COUNT_FILE="${WORK_DIR}/time_calls"
	printf '0' > "${CALL_COUNT_FILE}"

	currentTime() {
		COUNT=$(cat "${CALL_COUNT_FILE}")
		COUNT=$(( COUNT + 1 ))
		printf '%s' "${COUNT}" > "${CALL_COUNT_FILE}"
		case "${COUNT}" in
			1|2) echo 1000 ;;
			*) echo 1010 ;;
		esac
	}

	set_rtc_wakeup_absolute() {
		return 0
	}

	sleep() {
		:
	}

	LIPC_CALLS="${WORK_DIR}/lipc_calls"
	: > "${LIPC_CALLS}"
	lipc-wait-event() {
		echo "$*" >> "${LIPC_CALLS}"
	}

	run wait_for_suspend 5
	[ "${status}" -eq 0 ]
	grep -q "com.lab126.powerd" "${LIPC_CALLS}"
}

@test "logger buffers to temp file when LOGFILE is a path" {
	LOGGING=1
	LOGFILE="${WORK_DIR}/test.log"
	logger "buffered message"
	[ -f /tmp/onlinescreensaver.log ]
	grep -q "buffered message" /tmp/onlinescreensaver.log
	[ ! -f "${WORK_DIR}/test.log" ]
}

@test "flush_log_buffer moves buffer to LOGFILE when forced" {
	LOGGING=1
	LOGFILE="${WORK_DIR}/test.log"
	logger "to be flushed"
	flush_log_buffer force
	[ -f "${WORK_DIR}/test.log" ]
	grep -q "to be flushed" "${WORK_DIR}/test.log"
	[ ! -f /tmp/onlinescreensaver.log ]
}

@test "flush_log_buffer skips flush when userstore unavailable" {
	LOGGING=1
	LOGFILE="${WORK_DIR}/test.log"

	is_userstore_available() { return 1; }

	logger "stuck in buffer"
	flush_log_buffer force
	[ ! -f "${WORK_DIR}/test.log" ]
	grep -q "stuck in buffer" /tmp/onlinescreensaver.log
}

@test "logger writes directly to stderr without buffering" {
	LOGGING=1
	LOGFILE=/dev/stderr
	logger "direct message"
	[ ! -f /tmp/onlinescreensaver.log ]
}
