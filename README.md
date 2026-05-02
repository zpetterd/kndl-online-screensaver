# kndl-online-screensaver

A Kindle extension that downloads an image from a URL and displays it as the
screensaver. Supports multiple Kindle models with automatic device detection,
battery-efficient scheduling via RTC wakeup, and an optional image server with
resize support.

## Requirements

- Jailbroken Kindle running firmware 5.x+
- [KUAL](https://www.mobileread.com/forums/showthread.php?t=203326) installed
- [linkss screensaver hack](https://www.mobileread.com/forums/showthread.php?t=225030) installed
- An HTTP endpoint that serves a PNG image

## Quick start

1. Connect your Kindle via USB.
2. Run the installer from your computer:

```sh
./install.sh
```

3. Follow the prompts (mount path, image URL, schedule, WiFi behavior).
4. Safely eject the Kindle.
5. On the Kindle, open KUAL and tap **Kndl Online Screensaver** →
   **Enable auto-download**.
6. The screensaver updates on the next sleep cycle.

## Configuration

All settings are in `config.sh` on the Kindle at
`extensions/kndl-online-screensaver/bin/config.sh`.

| Variable          | Default                                      | Description |
|-------------------|----------------------------------------------|-------------|
| `IMAGE_URI`       | *(set during install)*                       | URL to download the screensaver PNG from |
| `SCHEDULE`        | `00:00-07:00=90 07:00-21:00=10 21:00-24:00=20` | Update schedule (see format below) |
| `DEFAULTINTERVAL` | `300`                                        | Fallback interval in minutes if no schedule matches |
| `DISABLE_WIFI`    | `0`                                          | Turn off WiFi between updates (1=yes) |
| `REQUEST_RESIZE`  | `0`                                          | Append `?w=W&h=H` to URL for server-side resize (1=yes) |
| `TEST_DOMAIN`     | `8.8.8.8`                                    | Domain to ping for connectivity check |
| `NETWORK_TIMEOUT` | `58`                                         | Seconds to wait for internet connection |
| `LOGGING`         | `0`                                          | Enable logging (1=yes) |
| `LOGFILE`         | `/dev/stderr`                                | Log destination |
| `RTC`             | `0`                                          | RTC device index (0, 1, or 2) |

### Schedule format

Space-separated list of time ranges with intervals in minutes:

```
SCHEDULE="HH:MM-HH:MM=INTERVAL HH:MM-HH:MM=INTERVAL ..."
```

Example - update every 90 minutes at night, every 10 minutes during the
day, every 20 minutes in the evening:

```
SCHEDULE="00:00-07:00=90 07:00-21:00=10 21:00-24:00=20"
```

## Image server (optional)

A simple Python server is included that serves a PNG image and optionally
resizes it to match the requesting device's screen resolution.

```sh
cd server
pip install Pillow
IMAGE_PATH=/path/to/your/image.png python server.py
```

The server listens on port 5000 (configurable via `PORT` env var):

- `GET /` - returns the source image as 8-bit grayscale PNG.
- `GET /?w=758&h=1024` - returns the image resized to 758×1024.

Set `REQUEST_RESIZE=1` in the Kindle's `config.sh` to have the device
automatically request the correct resolution.

## Device support

The extension auto-detects the Kindle model from the serial number and
selects the correct screen resolution and screensaver filename. See
[DEVICES.md](DEVICES.md) for the full compatibility matrix.

If your device is not recognized, resolution is detected via `eips -i`
as a fallback.

## Testing

```sh
# Shell scripts
shellcheck --severity=style kindle/bin/*.sh install.sh

# Bats tests
bats tests/*.bats

# Python server tests
tox
```

## Acknowledgments

This project merges and improves upon two existing projects:

- **Peterson** - original author of the online screensaver concept
  ([MobileRead thread](https://www.mobileread.com/forums/showthread.php?t=236104))
- **Nico Kuhn / onlinescreensaverPW2** - maintained fork with schedule
  support (MIT license)
- **64bits / Little-Langtale** - power management improvements (RTC
  wakeup, CPU powersave, timeout protection, WiFi on-demand)
- The **MobileRead community** for device testing and feedback

## License

MIT - see [LICENSE](LICENSE).
