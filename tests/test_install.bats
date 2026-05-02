#!/usr/bin/env bats

load helpers/setup

setup() {
	create_mock_kindle_mount
	INSTALL_SH="${BATS_TEST_DIRNAME}/../install.sh"
}

teardown() {
	teardown_mock_kindle_mount
}

run_install() {
	# Pipe answers to install.sh via stdin
	# Args: mount_path image_url schedule_choice wifi_choice resize_choice [overwrite_choice]
	{
		echo "${1}"    # mount path
		echo "${2}"    # image URL
		echo "${3}"    # schedule choice
		echo "${4}"    # wifi choice
		echo "${5}"    # resize choice
		if [ -n "${6}" ]; then
			echo "${6}"  # overwrite config choice
		fi
	} | sh "${INSTALL_SH}"
}

@test "install copies all extension files" {
	run_install "${KINDLE_MOUNT}" "http://example.com/image.png" "1" "Y" "N"

	INSTALL_DIR="${KINDLE_MOUNT}/extensions/onlinescreensaver"
	[ -f "${INSTALL_DIR}/menu.json" ]
	[ -f "${INSTALL_DIR}/config.xml" ]
	[ -f "${INSTALL_DIR}/bin/scheduler.sh" ]
	[ -f "${INSTALL_DIR}/bin/update.sh" ]
	[ -f "${INSTALL_DIR}/bin/utils.sh" ]
	[ -f "${INSTALL_DIR}/bin/device.sh" ]
	[ -f "${INSTALL_DIR}/bin/enable.sh" ]
	[ -f "${INSTALL_DIR}/bin/disable.sh" ]
	[ -f "${INSTALL_DIR}/bin/onlinescreensaver.conf" ]
	[ -f "${INSTALL_DIR}/bin/config.sh" ]
}

@test "install sets executable permissions on .sh files" {
	run_install "${KINDLE_MOUNT}" "http://example.com/image.png" "1" "Y" "N"

	INSTALL_DIR="${KINDLE_MOUNT}/extensions/onlinescreensaver"
	[ -x "${INSTALL_DIR}/bin/scheduler.sh" ]
	[ -x "${INSTALL_DIR}/bin/update.sh" ]
	[ -x "${INSTALL_DIR}/bin/enable.sh" ]
	[ -x "${INSTALL_DIR}/bin/disable.sh" ]
}

@test "install creates screensaver directory" {
	# Remove it first to test creation
	rm -rf "${KINDLE_MOUNT}/linkss/screensavers"

	run_install "${KINDLE_MOUNT}" "http://example.com/image.png" "1" "Y" "N"

	[ -d "${KINDLE_MOUNT}/linkss/screensavers" ]
}

@test "config.sh contains IMAGE_URI from prompt" {
	run_install "${KINDLE_MOUNT}" "http://myserver:5000/" "1" "Y" "N"

	CONFIG="${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/config.sh"
	grep -q 'IMAGE_URI="http://myserver:5000/"' "${CONFIG}"
}

@test "config.sh contains recommended schedule for choice 1" {
	run_install "${KINDLE_MOUNT}" "http://example.com/img.png" "1" "Y" "N"

	CONFIG="${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/config.sh"
	grep -q '00:00-07:00=90 07:00-21:00=10 21:00-24:00=20' "${CONFIG}"
}

@test "config.sh contains DISABLE_WIFI=1 when Y chosen" {
	run_install "${KINDLE_MOUNT}" "http://example.com/img.png" "1" "Y" "N"

	CONFIG="${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/config.sh"
	grep -q 'DISABLE_WIFI=1' "${CONFIG}"
}

@test "config.sh contains DISABLE_WIFI=0 when n chosen" {
	run_install "${KINDLE_MOUNT}" "http://example.com/img.png" "1" "n" "N"

	CONFIG="${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/config.sh"
	grep -q 'DISABLE_WIFI=0' "${CONFIG}"
}

@test "config.sh contains REQUEST_RESIZE=0 when N chosen" {
	run_install "${KINDLE_MOUNT}" "http://example.com/img.png" "1" "Y" "N"

	CONFIG="${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/config.sh"
	grep -q 'REQUEST_RESIZE=0' "${CONFIG}"
}

@test "config.sh contains REQUEST_RESIZE=1 when y chosen" {
	run_install "${KINDLE_MOUNT}" "http://example.com/img.png" "1" "Y" "y"

	CONFIG="${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/config.sh"
	grep -q 'REQUEST_RESIZE=1' "${CONFIG}"
}

@test "re-install removes old files and installs cleanly" {
	# First install
	run_install "${KINDLE_MOUNT}" "http://example.com/img.png" "1" "Y" "N"

	# Create a stale file that should be cleaned up
	echo "stale" > "${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/old_script.sh"

	# Re-install (overwrite config)
	run_install "${KINDLE_MOUNT}" "http://example.com/img.png" "1" "Y" "N" "y"

	[ ! -f "${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/old_script.sh" ]
	[ -f "${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/update.sh" ]
}

@test "re-install preserves existing config.sh when user declines overwrite" {
	# First install
	run_install "${KINDLE_MOUNT}" "http://first.example.com/" "1" "Y" "N"

	CONFIG="${KINDLE_MOUNT}/extensions/onlinescreensaver/bin/config.sh"
	grep -q 'http://first.example.com/' "${CONFIG}"

	# Second install — decline overwrite (answer 'n' to overwrite prompt)
	run_install "${KINDLE_MOUNT}" "http://second.example.com/" "1" "Y" "N" "n"

	# Config should still have the first URL
	grep -q 'http://first.example.com/' "${CONFIG}"
}

@test "install fails on non-existent mount path" {
	run run_install "/nonexistent/path" "http://example.com/" "1" "Y" "N"
	[ "${status}" -ne 0 ]
}

@test "install fails on non-Kindle directory" {
	FAKE_DIR="$(mktemp -d)"
	run run_install "${FAKE_DIR}" "http://example.com/" "1" "Y" "N"
	[ "${status}" -ne 0 ]
	rm -rf "${FAKE_DIR}"
}
