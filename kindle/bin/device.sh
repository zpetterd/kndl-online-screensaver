#!/bin/sh
# shellcheck disable=SC2034
##############################################################################
# Device auto-detection for Kindle
#
# Detects the Kindle model from the serial number prefix and derives the
# screen resolution and screensaver filename. Sourced by other scripts.
##############################################################################

# Detect device model, screen resolution (W x H), and screensaver filename.
# Sets: DEVICE, W, H, SCREENSAVER_BASENAME
get_device_info () {
	SERIAL_PREFIX=""
	if [ -f /proc/usid ]; then
		SERIAL_PREFIX=$(cut -c1-4 /proc/usid 2>/dev/null)
	fi

	case "${SERIAL_PREFIX}" in
		B004|B005|B024)
			DEVICE="kt2"  ; W=600  ; H=800  ;;
		B00E|B023)
			DEVICE="pw1"  ; W=758  ; H=1024 ;;
		B0D4|90D4)
			DEVICE="pw2"  ; W=758  ; H=1024 ;;
		G090|B0D5)
			DEVICE="pw3"  ; W=1072 ; H=1448 ;;
		B0D6|B0D7|B0D8)
			DEVICE="pw4"  ; W=1072 ; H=1448 ;;
		B0CE|B0CF)
			DEVICE="pw5"  ; W=1236 ; H=1648 ;;
		B0C6)
			DEVICE="voyage"; W=1072 ; H=1448 ;;
		B0DD)
			DEVICE="oasis1"; W=1072 ; H=1448 ;;
		B0DE|B0DF)
			DEVICE="oasis2"; W=1264 ; H=1680 ;;
		B0E0|B0E1)
			DEVICE="oasis3"; W=1264 ; H=1680 ;;
		B00F|B010|B011|B012)
			DEVICE="kt"   ; W=600  ; H=800  ;;
		*)
			# Fallback: parse eips output for resolution
			_dims=$(eips -i 2>&1 | sed -n 's/.*xres=\([0-9]*\).*yres=\([0-9]*\).*/\1 \2/p')
			read -r W H << EOF
${_dims}
EOF
			DEVICE="unknown"

			if [ -z "${W}" ] || [ -z "${H}" ]; then
				W=758
				H=1024
			fi
			;;
	esac

	SCREENSAVER_BASENAME="bg_ss00.png"
}
