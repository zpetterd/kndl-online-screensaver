#!/usr/bin/env bats

load helpers/setup

setup() {
	stub_kindle_commands
}

teardown() {
	teardown_mock_usid
}

# Helper: source device.sh with a mock /proc/usid
detect_with_serial() {
	create_mock_usid "$1"
	# Override /proc/usid path by replacing the function
	eval "$(sed "s|/proc/usid|$MOCK_PROC_DIR/usid|g" "$BATS_TEST_DIRNAME/../kindle/bin/device.sh")"
	get_device_info
}

# Helper: source device.sh with no /proc/usid (triggers eips fallback)
detect_with_eips() {
	MOCK_PROC_DIR="$(mktemp -d)"
	# No usid file exists in MOCK_PROC_DIR

	# Stub eips to return the given resolution
	eips() {
		echo "xres=$1 yres=$2"
	}
	export -f eips

	eval "$(sed "s|/proc/usid|$MOCK_PROC_DIR/usid|g" "$BATS_TEST_DIRNAME/../kindle/bin/device.sh")"
	get_device_info
}

@test "PW2 serial B0D4 → 758x1024, bg_ss00.png" {
	detect_with_serial "B0D4XXXXXXXXXXXX"
	[ "$DEVICE" = "pw2" ]
	[ "$W" -eq 758 ]
	[ "$H" -eq 1024 ]
	[ "$SCREENSAVER_BASENAME" = "bg_ss00.png" ]
}

@test "PW2 serial 90D4 → 758x1024, bg_ss00.png" {
	detect_with_serial "90D4XXXXXXXXXXXX"
	[ "$DEVICE" = "pw2" ]
	[ "$W" -eq 758 ]
	[ "$H" -eq 1024 ]
	[ "$SCREENSAVER_BASENAME" = "bg_ss00.png" ]
}

@test "PW1 serial B00E → 758x1024, bg_ss00.png" {
	detect_with_serial "B00EXXXXXXXXXXXX"
	[ "$DEVICE" = "pw1" ]
	[ "$W" -eq 758 ]
	[ "$H" -eq 1024 ]
	[ "$SCREENSAVER_BASENAME" = "bg_ss00.png" ]
}

@test "PW3 serial G090 → 1072x1448, bg_ss00.png" {
	detect_with_serial "G090XXXXXXXXXXXX"
	[ "$DEVICE" = "pw3" ]
	[ "$W" -eq 1072 ]
	[ "$H" -eq 1448 ]
	[ "$SCREENSAVER_BASENAME" = "bg_ss00.png" ]
}

@test "PW5 serial B0CE → 1236x1648, bg_ss00.png" {
	detect_with_serial "B0CEXXXXXXXXXXXX"
	[ "$DEVICE" = "pw5" ]
	[ "$W" -eq 1236 ]
	[ "$H" -eq 1648 ]
	[ "$SCREENSAVER_BASENAME" = "bg_ss00.png" ]
}

@test "Kindle Touch serial B004 → 600x800, bg_ss00.png" {
	detect_with_serial "B004XXXXXXXXXXXX"
	[ "$DEVICE" = "kt2" ]
	[ "$W" -eq 600 ]
	[ "$H" -eq 800 ]
	[ "$SCREENSAVER_BASENAME" = "bg_ss00.png" ]
}

@test "Voyage serial B0C6 → 1072x1448, bg_ss00.png" {
	detect_with_serial "B0C6XXXXXXXXXXXX"
	[ "$DEVICE" = "voyage" ]
	[ "$W" -eq 1072 ]
	[ "$H" -eq 1448 ]
	[ "$SCREENSAVER_BASENAME" = "bg_ss00.png" ]
}

@test "Oasis 2 serial B0DE → 1264x1680, bg_ss00.png" {
	detect_with_serial "B0DEXXXXXXXXXXXX"
	[ "$DEVICE" = "oasis2" ]
	[ "$W" -eq 1264 ]
	[ "$H" -eq 1680 ]
	[ "$SCREENSAVER_BASENAME" = "bg_ss00.png" ]
}

@test "Unknown serial falls back to eips" {
	create_mock_usid "ZZZZXXXXXXXXXXXX"

	eips() {
		echo "xres=1072 yres=1448"
	}
	export -f eips

	eval "$(sed "s|/proc/usid|$MOCK_PROC_DIR/usid|g" "$BATS_TEST_DIRNAME/../kindle/bin/device.sh")"
	get_device_info

	[ "$DEVICE" = "unknown" ]
	[ "$W" -eq 1072 ]
	[ "$H" -eq 1448 ]
	[ "$SCREENSAVER_BASENAME" = "bg_ss00.png" ]
}

@test "eips fallback parses multi-line output" {
	MOCK_PROC_DIR="$(mktemp -d)"

	eips() {
		printf '%s\n' "eips 2.0" "xres=1264 yres=1680"
	}
	export -f eips

	eval "$(sed "s|/proc/usid|$MOCK_PROC_DIR/usid|g" "$BATS_TEST_DIRNAME/../kindle/bin/device.sh")"
	get_device_info

	[ "$DEVICE" = "unknown" ]
	[ "$W" -eq 1264 ]
	[ "$H" -eq 1680 ]
}

@test "No usid and no eips defaults to 758x1024" {
	MOCK_PROC_DIR="$(mktemp -d)"

	eips() {
		echo "some error output"
	}
	export -f eips

	eval "$(sed "s|/proc/usid|$MOCK_PROC_DIR/usid|g" "$BATS_TEST_DIRNAME/../kindle/bin/device.sh")"
	get_device_info

	[ "$DEVICE" = "unknown" ]
	[ "$W" -eq 758 ]
	[ "$H" -eq 1024 ]
}
