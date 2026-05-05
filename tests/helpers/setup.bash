#!/usr/bin/env bash
# Shared test helpers for bats tests.
# Creates a mock Kindle USB mount directory and stubs Kindle-specific commands
# so that the extension scripts can be sourced without a real device.

# Create a temporary directory mimicking a Kindle USB mount.
# Sets KINDLE_MOUNT to the path.
create_mock_kindle_mount() {
    KINDLE_MOUNT="$(mktemp -d)"
    mkdir -p "$KINDLE_MOUNT/documents"
    mkdir -p "$KINDLE_MOUNT/system"
    mkdir -p "$KINDLE_MOUNT/extensions"
    mkdir -p "$KINDLE_MOUNT/linkss/screensavers"
}

# Remove the mock Kindle mount directory.
teardown_mock_kindle_mount() {
    if [ -n "$KINDLE_MOUNT" ] && [ -d "$KINDLE_MOUNT" ]; then
        rm -rf "$KINDLE_MOUNT"
    fi
}

# Stub Kindle-specific commands as shell functions.
# These do nothing (or return canned values) so scripts can be sourced.
stub_kindle_commands() {
    eips() {
        :
    }
    export -f eips

    lipc-get-prop() {
        case "$1/$2" in
            com.lab126.powerd/status)
                echo "Screen Saver"
                ;;
            com.lab126.cmd/wirelessEnable)
                echo "1"
                ;;
            com.lab126.wifid/cmState)
                echo "CONNECTED"
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
        :
    }
    export -f lipc-set-prop

    lipc-wait-event() {
        :
    }
    export -f lipc-wait-event

    mntroot() {
        :
    }
    export -f mntroot

    ping() {
        return 0
    }
    export -f ping

    gasgauge-info() {
        echo "42"
    }
    export -f gasgauge-info
}

# Create a mock /proc/usid file in a temp directory.
# Usage: create_mock_usid "B0D4XXXXXXXXXXXX"
# Sets MOCK_PROC_DIR to the directory containing the mock usid file.
create_mock_usid() {
    MOCK_PROC_DIR="$(mktemp -d)"
    printf '%s' "$1" > "$MOCK_PROC_DIR/usid"
}

teardown_mock_usid() {
    if [ -n "$MOCK_PROC_DIR" ] && [ -d "$MOCK_PROC_DIR" ]; then
        rm -rf "$MOCK_PROC_DIR"
    fi
}
