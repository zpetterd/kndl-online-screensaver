# kndl-online-screensaver

A Kindle extension that downloads an image from a URL and displays it as the
screensaver. Supports multiple Kindle models with automatic device detection,
battery-efficient scheduling via RTC wakeup, and an optional image server with
resize support.

Designed to work with
[hass-eink-dashboard](https://github.com/cryptomilk/hass-eink-dashboard/), a
Home Assistant custom component that renders e-ink dashboard images as PNG, but
works with any HTTP endpoint serving a PNG image.

## Features

- **Flexible scheduling** - time-of-day intervals (e.g. frequent during the
  day, infrequent at night)
- **Power management** - RTC wakeup, CPU powersave, WiFi on-demand
- **Efficient WiFi** - polls connection state instead of fixed sleep, connects
  in ~5 seconds
- **ETag caching** - skips image download when unchanged (304 Not Modified)
- **Battery reporting** - sends battery level and charging state to the server
- **Auto device detection** - identifies Kindle model and screen resolution
  from serial number
- **Server-side resize** - optional grayscale conversion and
  aspect-ratio-preserving resize

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
5. On the Kindle, open KUAL and tap **Online Screensaver** →
   **Enable auto-download**.
6. The screensaver updates on the next sleep cycle.

## Updating

After copying updated script files to the Kindle, the running service must be
restarted to pick up the changes. Open KUAL and tap **Online Screensaver** →
**Restart auto-download**.

## Configuration

All settings are in `config.sh` on the Kindle at
`extensions/onlinescreensaver/bin/config.sh`.

| Variable          | Default                                      | Description |
|-------------------|----------------------------------------------|-------------|
| `IMAGE_URI`       | *(set during install)*                       | URL to download the screensaver PNG from |
| `SCHEDULE`        | `00:00-07:00=60 07:00-21:00=8 21:00-24:00=15` | Update schedule (see format below) |
| `DEFAULTINTERVAL` | `60`                                         | Fallback interval in minutes if no schedule matches |
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

Example - update every 60 minutes at night, every 8 minutes during the
day, every 15 minutes in the evening:

```
SCHEDULE="00:00-07:00=60 07:00-21:00=8 21:00-24:00=15"
```

With `SCHEDULE="00:00-07:00=80 07:00-21:00=10 21:00-24:00=20"` battery
drain is roughly 8-9% per day on a Kindle Paperwhite 2.

## Image server (optional)

A simple Python server is included that serves a PNG image and optionally
resizes it to match the requesting device's screen resolution.

```sh
cd server
pip install Pillow
python server.py --image /path/to/your/image.png
```

| Argument  | Default                   | Description |
|-----------|---------------------------|-------------|
| `--image` | `IMAGE_PATH` env or `testimage.png` | Path to the source image |
| `--port`  | `PORT` env or `5000`      | Port to listen on |

- `GET /` - returns the source image as 8-bit grayscale PNG
- `GET /?w=758&h=1024` - returns the image resized to 758×1024
- Supports ETag caching (304 Not Modified) to avoid redundant transfers

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

## Debugging

Enable logging in `config.sh`:

```sh
LOGGING=1
LOGFILE=/mnt/us/extensions/onlinescreensaver/log/onlinescreensaver.log
```

Logs are buffered in RAM (`/tmp/onlinescreensaver.log`) and flushed to
the FAT partition periodically and on clean shutdown. To collect a log:

1. On the Kindle, open KUAL → **Online Screensaver** → **Disable auto-download**
   (this flushes the buffer to disk)
2. Connect the Kindle via USB
3. Copy the log file from `extensions/onlinescreensaver/log/`
4. Copy any updated scripts, then safely eject
5. Re-enable auto-download via KUAL

**Important:** always disable auto-download before connecting USB.
Stopping the service ensures the log is fully flushed and that no
scripts hold open file handles on the FAT partition.

## Acknowledgments

This project merges and improves upon two existing projects:

- **Peterson** - original author of the online screensaver concept
  ([MobileRead thread](https://www.mobileread.com/forums/showthread.php?t=236104))
- **Nico Kuhn / [onlinescreensaverPW2](https://github.com/Kuhno92/onlinescreensaverPW2)** - maintained fork with schedule
  support (MIT license)
- **64bits / [Little-Langtale](https://github.com/64bits/Little-Langtale/)** - power management improvements (RTC
  wakeup, CPU powersave, timeout protection, WiFi on-demand)
- The **MobileRead community** for device testing and feedback

## License

MIT - see [LICENSE](LICENSE).
