#!/usr/bin/env bats

load helpers/setup

setup() {
	stub_kindle_commands

	WORK_DIR="$(mktemp -d)"
	SCREENSAVER_DIR="${WORK_DIR}/screensavers"
	mkdir -p "${SCREENSAVER_DIR}"

	cp "${BATS_TEST_DIRNAME}/../kindle/bin/update.sh" "${WORK_DIR}/"
	cp "${BATS_TEST_DIRNAME}/../kindle/bin/utils.sh" "${WORK_DIR}/"

	cat > "${WORK_DIR}/config.sh" <<-'CONF'
	IMAGE_URI="http://example.com/image.png"
	TMPFILE="/tmp/test_update_tmp.png"
	LOGGING=0
	LOGFILE=/dev/stderr
	REQUEST_RESIZE=0
	DISABLE_WIFI=0
	TEST_DOMAIN="8.8.8.8"
	NETWORK_TIMEOUT=1
	CONF
	SCREENSAVERFILE="${SCREENSAVER_DIR}/bg_ss00.png"
	echo "SCREENSAVERFILE=${SCREENSAVERFILE}" >> "${WORK_DIR}/config.sh"

	# Stub /bin/ping so the connectivity loop succeeds
	mkdir -p "${WORK_DIR}/bin"
	cat > "${WORK_DIR}/bin/ping" <<-'PING'
	#!/bin/sh
	exit 0
	PING
	chmod +x "${WORK_DIR}/bin/ping"

	# Stub sleep to avoid delays
	sleep() { :; }
	export -f sleep

	WGET_CALLS="${WORK_DIR}/wget_calls"
	: > "${WGET_CALLS}"
}

teardown() {
	rm -rf "${WORK_DIR}"
	rm -f /tmp/test_update_tmp.png
	rm -f /tmp/.online_screensaver_etag
}

stub_wget_success() {
	WGET_CALLS_FILE="$1"
	export WGET_CALLS_FILE
	HEADERS_CONTENT="${2:-}"
	export HEADERS_CONTENT
	wget() {
		echo "$*" >> "${WGET_CALLS_FILE}"
		# Find -O argument and write fake image data
		while [ $# -gt 0 ]; do
			case "$1" in
				-O) shift; printf 'PNG_DATA' > "$1" ;;
			esac
			shift
		done
		# Write response headers to stderr (redirected to HEADERS_FILE by update.sh)
		if [ -n "${HEADERS_CONTENT}" ]; then
			printf '%s\n' "${HEADERS_CONTENT}" >&2
		else
			printf '  HTTP/1.1 200 OK\n  ETag: abc123\n' >&2
		fi
		return 0
	}
	export -f wget
}

stub_wget_304() {
	WGET_CALLS_FILE="$1"
	export WGET_CALLS_FILE
	wget() {
		echo "$*" >> "${WGET_CALLS_FILE}"
		printf '  HTTP/1.1 304 Not Modified\n' >&2
		return 0
	}
	export -f wget
}

stub_wget_failure() {
	WGET_CALLS_FILE="$1"
	export WGET_CALLS_FILE
	wget() {
		echo "$*" >> "${WGET_CALLS_FILE}"
		printf '  HTTP/1.1 500 Internal Server Error\n' >&2
		return 1
	}
	export -f wget
}

@test "battery params appended to fetch URL" {
	stub_wget_success "${WGET_CALLS}"

	run env PATH="${WORK_DIR}/bin:${PATH}" bash "${WORK_DIR}/update.sh"
	[ "${status}" -eq 0 ]

	WGET_LINE=$(cat "${WGET_CALLS}")
	echo "wget args: ${WGET_LINE}"
	[[ "${WGET_LINE}" == *"batteryLevel=42"* ]]
	[[ "${WGET_LINE}" == *"isCharging="* ]]
}

@test "battery params use & separator when resize params present" {
	sed -i 's/REQUEST_RESIZE=0/REQUEST_RESIZE=1/' "${WORK_DIR}/config.sh"
	# Add device dimensions
	cat >> "${WORK_DIR}/config.sh" <<-'CONF'
	W=758
	H=1024
	CONF

	stub_wget_success "${WGET_CALLS}"

	run env PATH="${WORK_DIR}/bin:${PATH}" bash "${WORK_DIR}/update.sh"
	[ "${status}" -eq 0 ]

	WGET_LINE=$(cat "${WGET_CALLS}")
	echo "wget args: ${WGET_LINE}"
	[[ "${WGET_LINE}" == *"?w=758&h=1024&batteryLevel=42"* ]]
}

@test "etag sent when etag file exists" {
	printf 'abc123' > /tmp/.online_screensaver_etag

	stub_wget_success "${WGET_CALLS}"

	run env PATH="${WORK_DIR}/bin:${PATH}" bash "${WORK_DIR}/update.sh"
	[ "${status}" -eq 0 ]

	WGET_LINE=$(cat "${WGET_CALLS}")
	echo "wget args: ${WGET_LINE}"
	[[ "${WGET_LINE}" == *'If-None-Match: abc123'* ]]
}

@test "no etag header when etag file missing" {
	stub_wget_success "${WGET_CALLS}"

	run env PATH="${WORK_DIR}/bin:${PATH}" bash "${WORK_DIR}/update.sh"
	[ "${status}" -eq 0 ]

	WGET_LINE=$(cat "${WGET_CALLS}")
	echo "wget args: ${WGET_LINE}"
	[[ "${WGET_LINE}" != *"If-None-Match"* ]]
}

@test "304 response skips image update" {
	printf 'old_etag' > /tmp/.online_screensaver_etag

	stub_wget_304 "${WGET_CALLS}"

	run env PATH="${WORK_DIR}/bin:${PATH}" bash "${WORK_DIR}/update.sh"
	[ "${status}" -eq 0 ]

	# Screensaver file should NOT exist (no image was written)
	[ ! -f "${SCREENSAVERFILE}" ]
}

@test "new etag saved from response headers" {
	stub_wget_success "${WGET_CALLS}"

	run env PATH="${WORK_DIR}/bin:${PATH}" bash "${WORK_DIR}/update.sh"
	[ "${status}" -eq 0 ]

	[ -f /tmp/.online_screensaver_etag ]
	SAVED_ETAG=$(cat /tmp/.online_screensaver_etag)
	[ "${SAVED_ETAG}" = "abc123" ]
}

@test "successful download refreshes screen via eips" {
	EIPS_CALLS="${WORK_DIR}/eips_calls"
	eips() { echo "$*" >> "${EIPS_CALLS}"; }
	export -f eips
	export EIPS_CALLS

	stub_wget_success "${WGET_CALLS}"

	run env PATH="${WORK_DIR}/bin:${PATH}" EIPS_CALLS="${EIPS_CALLS}" bash "${WORK_DIR}/update.sh"
	[ "${status}" -eq 0 ]

	[ -f "${EIPS_CALLS}" ]
	grep -q '\-f \-g' "${EIPS_CALLS}"
}

@test "wget failure does not refresh screen" {
	EIPS_CALLS="${WORK_DIR}/eips_calls"
	eips() { echo "$*" >> "${EIPS_CALLS}"; }
	export -f eips
	export EIPS_CALLS

	stub_wget_failure "${WGET_CALLS}"

	run env PATH="${WORK_DIR}/bin:${PATH}" EIPS_CALLS="${EIPS_CALLS}" bash "${WORK_DIR}/update.sh"

	[ ! -f "${EIPS_CALLS}" ]
}

@test "WiFi cycled when enabled but stuck in NA state, DISABLE_WIFI not forced" {
	stub_wget_success "${WGET_CALLS}"

	# cmState returns "NA" on first call, "CONNECTED" on all subsequent calls
	CMSTATE_COUNTER="${WORK_DIR}/cmstate_counter"
	printf '0' > "${CMSTATE_COUNTER}"
	export CMSTATE_COUNTER

	LIPC_SET_CALLS="${WORK_DIR}/lipc_set_calls"
	: > "${LIPC_SET_CALLS}"
	export LIPC_SET_CALLS

	lipc-get-prop() {
		case "$1/$2" in
			com.lab126.cmd/wirelessEnable)
				echo "1"
				;;
			com.lab126.wifid/cmState)
				COUNT=$(cat "${CMSTATE_COUNTER}")
				COUNT=$((COUNT + 1))
				printf '%s' "${COUNT}" > "${CMSTATE_COUNTER}"
				if [ "${COUNT}" -eq 1 ]; then
					echo "NA"
				else
					echo "CONNECTED"
				fi
				;;
			com.lab126.powerd/status)
				echo "Screen Saver"
				;;
			com.lab126.powerd/isCharging)
				echo "0"
				;;
			com.lab126.volumd/userstoreIsAvailable)
				echo "1"
				;;
			*)
				echo ""
				;;
		esac
	}
	export -f lipc-get-prop

	lipc-set-prop() {
		echo "$*" >> "${LIPC_SET_CALLS}"
	}
	export -f lipc-set-prop

	run env PATH="${WORK_DIR}/bin:${PATH}" bash "${WORK_DIR}/update.sh"
	[ "${status}" -eq 0 ]

	# WiFi was cycled: disable then enable
	grep -q "com.lab126.cmd wirelessEnable 0" "${LIPC_SET_CALLS}"
	grep -q "com.lab126.cmd wirelessEnable 1" "${LIPC_SET_CALLS}"

	# DISABLE_WIFI must stay 0 (WiFi was already on) — no final disable call
	[ "$(grep -c "wirelessEnable 0" "${LIPC_SET_CALLS}")" -eq 1 ]
}
