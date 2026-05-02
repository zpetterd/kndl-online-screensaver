#!/usr/bin/env bats

load helpers/setup

setup() {
	stub_kindle_commands

	WORK_DIR="$(mktemp -d)"
	cp "${BATS_TEST_DIRNAME}/../kindle/bin/utils.sh" "${WORK_DIR}/"

	LOGGING=0
	LOGFILE=/dev/stderr
	RTC=0

	cd "${WORK_DIR}" || return 1
	# shellcheck disable=SC1091
	. ./utils.sh
}

teardown() {
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
	[ -f "${WORK_DIR}/test.log" ]
	grep -q "hello world" "${WORK_DIR}/test.log"
}

@test "logger output contains timestamp" {
	LOGGING=1
	LOGFILE="${WORK_DIR}/test.log"
	logger "test message"
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
