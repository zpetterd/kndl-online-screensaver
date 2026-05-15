#!/bin/sh
##############################################################################
# kndl-online-screensaver installer
#
# Runs on the host (Linux/macOS) while the Kindle is USB-mounted.
# Prompts for settings, copies extension files, and generates config.sh.
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXTENSION_NAME="onlinescreensaver"

##############################################################################
# Helpers

print_header() {
	echo ""
	echo "kndl-online-screensaver installer"
	echo "=================================="
	echo ""
}

prompt() {
	printf '%s' "${1}"
	read -r REPLY
	echo "${REPLY}"
}

die() {
	echo "Error: ${1}" >&2
	exit 1
}

check_mark() {
	echo "  + ${1}"
}

##############################################################################
# 1. Prompt for Kindle mount path

print_header

DEFAULT_MOUNT="/media/kindle"
if [ -d "/run/media/${USER}/Kindle" ]; then
	DEFAULT_MOUNT="/run/media/${USER}/Kindle"
fi
printf 'Kindle mount path [%s]: ' "${DEFAULT_MOUNT}"
read -r KINDLE_MOUNT
KINDLE_MOUNT="${KINDLE_MOUNT:-${DEFAULT_MOUNT}}"

# Validate mount path
if [ ! -d "${KINDLE_MOUNT}" ]; then
	die "Directory not found: ${KINDLE_MOUNT}"
fi

if [ -d "${KINDLE_MOUNT}/documents" ] || [ -d "${KINDLE_MOUNT}/system" ]; then
	check_mark "Found Kindle at ${KINDLE_MOUNT}"
else
	die "Does not look like a Kindle mount (no documents/ or system/ directory): ${KINDLE_MOUNT}"
fi

# Check for extensions directory
if [ -d "${KINDLE_MOUNT}/extensions" ]; then
	check_mark "Detected: extensions/ directory exists"
else
	echo "  ! Warning: extensions/ directory not found. Creating it."
	mkdir -p "${KINDLE_MOUNT}/extensions"
fi

# Check for linkss screensaver hack
if [ -d "${KINDLE_MOUNT}/linkss" ]; then
	check_mark "Detected: linkss/ screensaver hack installed"
else
	echo "  ! Warning: linkss/ directory not found."
	echo "    The screensaver hack must be installed for this extension to work."
	echo "    Continuing anyway — you can install it later."
fi

##############################################################################
# 2. Check for existing config.sh

INSTALL_DIR="${KINDLE_MOUNT}/extensions/${EXTENSION_NAME}"
SAVED_CONFIG=""
if [ -f "${INSTALL_DIR}/bin/config.sh" ]; then
	printf '\n  Existing config.sh found. Overwrite? [y/N]: '
	read -r OVERWRITE_CHOICE
	case "${OVERWRITE_CHOICE}" in
		[yY]*) ;;
		*)
			SAVED_CONFIG="$(cat "${INSTALL_DIR}/bin/config.sh")"
			;;
	esac
fi

if [ -z "${SAVED_CONFIG}" ]; then

##############################################################################
# 3. Prompt for image URL

echo ""
printf 'Image URL (e.g. http://192.168.1.10:5000):\n  > '
read -r IMAGE_URI
if [ -z "${IMAGE_URI}" ]; then
	die "Image URL cannot be empty."
fi

##############################################################################
# 4. Prompt for update schedule

echo ""
echo "Update schedule (how often to fetch a new image):"
echo "  1) Night 60min / Day 8min / Evening 15min  (recommended)"
echo "  2) Every  5 minutes"
echo "  3) Every 10 minutes"
echo "  4) Every 15 minutes"
echo "  5) Every 30 minutes"
echo "  6) Every 60 minutes"
echo "  7) Every 6 hours             (lowest battery usage)"
echo "  8) Custom schedule"
printf '  > '
read -r SCHEDULE_CHOICE

case "${SCHEDULE_CHOICE}" in
	1|"") SCHEDULE="00:00-07:00=60 07:00-21:00=8 21:00-24:00=15" ;;
	2) SCHEDULE="00:00-24:00=5" ;;
	3) SCHEDULE="00:00-24:00=10" ;;
	4) SCHEDULE="00:00-24:00=15" ;;
	5) SCHEDULE="00:00-24:00=30" ;;
	6) SCHEDULE="00:00-24:00=60" ;;
	7) SCHEDULE="00:00-24:00=360" ;;
	8)
		echo ""
		echo "  Enter custom schedule (format: HH:MM-HH:MM=INTERVAL ...)"
		echo "  Example: 00:00-07:00=90 07:00-21:00=10 21:00-24:00=20"
		printf '  > '
		read -r SCHEDULE
		if [ -z "${SCHEDULE}" ]; then
			die "Schedule cannot be empty."
		fi
		;;
	*)
		die "Invalid choice: ${SCHEDULE_CHOICE}"
		;;
esac

##############################################################################
# 5. Prompt for WiFi behavior

echo ""
printf 'Manage WiFi between updates (off for intervals >30 min, on otherwise)? [Y/n]: '
read -r WIFI_CHOICE
case "${WIFI_CHOICE}" in
	[nN]*) DISABLE_WIFI=0 ;;
	*)     DISABLE_WIFI=1 ;;
esac

##############################################################################
# 6. Prompt for server-side resize

echo ""
printf 'Request server-side image resize (requires compatible server)? [y/N]: '
read -r RESIZE_CHOICE
case "${RESIZE_CHOICE}" in
	[yY]*) REQUEST_RESIZE=1 ;;
	*)     REQUEST_RESIZE=0 ;;
esac

fi # end: if [ -z "${SAVED_CONFIG}" ]

##############################################################################
# 7. Install files

echo ""
echo "Installing to ${INSTALL_DIR}/ ..."

# Clean install — remove old files first
if [ -d "${INSTALL_DIR}" ]; then
	rm -rf "${INSTALL_DIR}"
	check_mark "Removed old ${EXTENSION_NAME} directory"
fi

# Copy extension files
mkdir -p "${INSTALL_DIR}/bin"
cp "${SCRIPT_DIR}/kindle/menu.json" "${INSTALL_DIR}/"
cp "${SCRIPT_DIR}/kindle/config.xml" "${INSTALL_DIR}/"
cp "${SCRIPT_DIR}/kindle/bin/scheduler.sh" "${INSTALL_DIR}/bin/"
cp "${SCRIPT_DIR}/kindle/bin/update.sh" "${INSTALL_DIR}/bin/"
cp "${SCRIPT_DIR}/kindle/bin/utils.sh" "${INSTALL_DIR}/bin/"
cp "${SCRIPT_DIR}/kindle/bin/device.sh" "${INSTALL_DIR}/bin/"
cp "${SCRIPT_DIR}/kindle/bin/enable.sh" "${INSTALL_DIR}/bin/"
cp "${SCRIPT_DIR}/kindle/bin/disable.sh" "${INSTALL_DIR}/bin/"
cp "${SCRIPT_DIR}/kindle/bin/restart.sh" "${INSTALL_DIR}/bin/"
cp "${SCRIPT_DIR}/kindle/bin/onlinescreensaver.conf" "${INSTALL_DIR}/bin/"
mkdir -p "${INSTALL_DIR}/log"
check_mark "Copied extension files"

# Set permissions
chmod +x "${INSTALL_DIR}/bin/"*.sh
check_mark "Set script permissions (chmod +x)"

# Create screensaver directory
if [ ! -d "${KINDLE_MOUNT}/linkss/screensavers" ]; then
	mkdir -p "${KINDLE_MOUNT}/linkss/screensavers"
	check_mark "Created screensaver directory (linkss/screensavers/)"
fi

# Generate or restore config.sh
if [ -n "${SAVED_CONFIG}" ]; then
	printf '%s\n' "${SAVED_CONFIG}" > "${INSTALL_DIR}/bin/config.sh"
	echo "  - Restored existing config.sh"
else
	sed \
		-e "s|^IMAGE_URI=.*|IMAGE_URI=\"${IMAGE_URI}\"|" \
		-e "s|^SCHEDULE=.*|SCHEDULE=\"${SCHEDULE}\"|" \
		-e "s|^DISABLE_WIFI=.*|DISABLE_WIFI=${DISABLE_WIFI}|" \
		-e "s|^REQUEST_RESIZE=.*|REQUEST_RESIZE=${REQUEST_RESIZE}|" \
		"${SCRIPT_DIR}/kindle/bin/config.sh" \
		> "${INSTALL_DIR}/bin/config.sh"
	check_mark "Wrote config.sh with your settings"
fi

echo ""
echo "Done! Safely eject your Kindle, then:"
echo "  1. Open KUAL on the Kindle"
echo "  2. Tap \"${EXTENSION_NAME}\" -> \"Enable auto-download\""
echo "  3. The screensaver will update on the next sleep cycle"
echo ""
