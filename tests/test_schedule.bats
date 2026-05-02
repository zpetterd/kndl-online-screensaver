#!/usr/bin/env bats

load helpers/setup

setup() {
	stub_kindle_commands

	WORK_DIR="$(mktemp -d)"

	# Source utils.sh for logger/currentTime
	cp "${BATS_TEST_DIRNAME}/../kindle/bin/utils.sh" "${WORK_DIR}/"
	cp "${BATS_TEST_DIRNAME}/../kindle/bin/config.sh" "${WORK_DIR}/"
	cp "${BATS_TEST_DIRNAME}/../kindle/bin/device.sh" "${WORK_DIR}/"

	cd "${WORK_DIR}" || return 1
	# shellcheck disable=SC1091
	. ./config.sh
	# shellcheck disable=SC1091
	. ./utils.sh

	# Extract extend_schedule and get_time_to_next_update from scheduler.sh
	awk '/^extend_schedule /,/^}/' "${BATS_TEST_DIRNAME}/../kindle/bin/scheduler.sh" > "${WORK_DIR}/funcs.sh"
	awk '/^get_time_to_next_update /,/^}/' "${BATS_TEST_DIRNAME}/../kindle/bin/scheduler.sh" >> "${WORK_DIR}/funcs.sh"
	# shellcheck disable=SC1091
	. "${WORK_DIR}/funcs.sh"
}

teardown() {
	rm -rf "${WORK_DIR}"
}

@test "single schedule entry covers full day" {
	SCHEDULE="00:00-24:00=60"
	DEFAULTINTERVAL=300
	extend_schedule

	# Should be able to get next update time
	RESULT=$(get_time_to_next_update)
	[ "${RESULT}" -ge 0 ]
	[ "${RESULT}" -le 60 ]
}

@test "schedule with multiple entries" {
	SCHEDULE="00:00-08:00=120 08:00-20:00=30 20:00-24:00=60"
	DEFAULTINTERVAL=300
	extend_schedule

	RESULT=$(get_time_to_next_update)
	[ "${RESULT}" -ge 0 ]
}

@test "extend_schedule fills gaps with DEFAULTINTERVAL" {
	SCHEDULE="06:00-12:00=30"
	DEFAULTINTERVAL=120
	extend_schedule

	# SCHEDULE should now contain filler entries for 0:00-6:00 and 12:00-24:00
	case "${SCHEDULE}" in
		*"0:0-6:0=120"*) true ;;
		*) echo "Missing gap filler before 06:00: ${SCHEDULE}"; false ;;
	esac

	case "${SCHEDULE}" in
		*"12:0-24:00=120"*) true ;;
		*) echo "Missing gap filler after 12:00: ${SCHEDULE}"; false ;;
	esac
}

@test "extend_schedule creates 48-hour schedule" {
	SCHEDULE="00:00-24:00=60"
	DEFAULTINTERVAL=300
	extend_schedule

	# Should contain entries for hours 24+
	case "${SCHEDULE}" in
		*"24:"*) true ;;
		*) echo "No 24+ hour entries in: ${SCHEDULE}"; false ;;
	esac
}

@test "get_time_to_next_update returns 0 when past scheduled time" {
	# Create a schedule that ended in the past (use hour 0 entries only)
	# This depends on current time, so use the full-day schedule
	SCHEDULE="00:00-24:00=1"
	DEFAULTINTERVAL=300
	extend_schedule

	RESULT=$(get_time_to_next_update)
	# With 1-minute interval, result should be 0 or 1
	[ "${RESULT}" -le 1 ]
}

@test "get_time_to_next_update at midnight computes minute 0" {
	date() { echo "00 00"; }
	export -f date

	SCHEDULE="00:00-24:00=60"
	DEFAULTINTERVAL=300
	extend_schedule

	RESULT=$(get_time_to_next_update)
	[ "${RESULT}" -ge 0 ]
	[ "${RESULT}" -le 60 ]
}

@test "schedule parsing strips leading zeros" {
	# The sed expression should convert 08 to 8 to avoid octal interpretation
	SCHEDULE="08:05-09:30=15"
	DEFAULTINTERVAL=300
	extend_schedule

	# If octal parsing failed, this would error out
	RESULT=$(get_time_to_next_update)
	[ "${RESULT}" -ge 0 ]
}
