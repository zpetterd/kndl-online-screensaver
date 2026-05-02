#!/usr/bin/env bats

load helpers/setup

setup() {
	stub_kindle_commands
	CONFIG_DIR="$(mktemp -d)"
	cp "${BATS_TEST_DIRNAME}/../kindle/bin/config.sh" "${CONFIG_DIR}/"
	cp "${BATS_TEST_DIRNAME}/../kindle/bin/device.sh" "${CONFIG_DIR}/"
}

teardown() {
	rm -rf "${CONFIG_DIR}"
}

source_config() {
	cd "${CONFIG_DIR}" || return 1
	# shellcheck disable=SC1091
	. ./config.sh
}

@test "DEFAULTINTERVAL defaults to 300" {
	source_config
	[ "${DEFAULTINTERVAL}" -eq 300 ]
}

@test "SCHEDULE has a value" {
	source_config
	[ -n "${SCHEDULE}" ]
}

@test "IMAGE_URI has a placeholder value" {
	source_config
	[ -n "${IMAGE_URI}" ]
}

@test "SCREENSAVERFOLDER defaults to linkss path" {
	source_config
	[ "${SCREENSAVERFOLDER}" = "/mnt/us/linkss/screensavers/" ]
}

@test "SCREENSAVERFILE includes SCREENSAVERFOLDER" {
	source_config
	case "${SCREENSAVERFILE}" in
		/mnt/us/linkss/screensavers/*) true ;;
		*) false ;;
	esac
}

@test "LOGGING defaults to 0" {
	source_config
	[ "${LOGGING}" -eq 0 ]
}

@test "DISABLE_WIFI defaults to 0" {
	source_config
	[ "${DISABLE_WIFI}" -eq 0 ]
}

@test "TEST_DOMAIN defaults to 8.8.8.8" {
	source_config
	[ "${TEST_DOMAIN}" = "8.8.8.8" ]
}

@test "NETWORK_TIMEOUT defaults to 58" {
	source_config
	[ "${NETWORK_TIMEOUT}" -eq 58 ]
}

@test "RTC defaults to 0" {
	source_config
	[ "${RTC}" -eq 0 ]
}

@test "user override of SCHEDULE takes effect" {
	echo 'SCHEDULE="06:00-18:00=30"' >> "${CONFIG_DIR}/config.sh"
	source_config
	[ "${SCHEDULE}" = "06:00-18:00=30" ]
}

@test "octal-safe time arithmetic with 10# prefix" {
	HOUR=08
	MINUTE=09
	RESULT=$(( 10#${HOUR} * 60 + 10#${MINUTE} ))
	[ "${RESULT}" -eq 489 ]
}
