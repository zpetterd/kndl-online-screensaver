# Device compatibility matrix

The screensaver image must exactly match the device's screen resolution.
`device.sh` auto-detects the model from the serial number prefix and
selects the correct resolution and screensaver filename.

| Device           | Year | Resolution    | PPI | Screen | Screensaver filename | Serial prefix |
|------------------|------|---------------|-----|--------|----------------------|---------------|
| Kindle 4/Touch   | 2011 | 600 × 800    | 167 | 6"     | bg_ss00.png          | B00F-B012     |
| Kindle Touch 2   | 2012 | 600 × 800    | 167 | 6"     | bg_ss00.png          | B004,B005,B024|
| Kindle 7 (7th)   | 2014 | 600 × 800    | 167 | 6"     | bg_ss00.png          |               |
| Kindle 8 (8th)   | 2016 | 600 × 800    | 167 | 6"     | bg_ss00.png          |               |
| Kindle 10 (10th) | 2019 | 600 × 800    | 167 | 6"     | bg_ss00.png          |               |
| Kindle 11 (11th) | 2022 | 1072 × 1448  | 300 | 6"     | bg_ss00.png          |               |
| PW1              | 2012 | 758 × 1024   | 212 | 6"     | bg_medium_ss00.png   | B00E,B023     |
| PW2              | 2013 | 758 × 1024   | 212 | 6"     | bg_medium_ss00.png   | B0D4,90D4     |
| PW3              | 2015 | 1072 × 1448  | 300 | 6"     | bg_ss00.png          | G090,B0D5     |
| PW4              | 2018 | 1072 × 1448  | 300 | 6"     | bg_ss00.png          | B0D6-B0D8     |
| PW5              | 2021 | 1236 × 1648  | 300 | 6.8"   | bg_ss00.png          | B0CE,B0CF     |
| Voyage           | 2014 | 1072 × 1448  | 300 | 6"     | bg_ss00.png          | B0C6          |
| Oasis 1          | 2016 | 1072 × 1448  | 300 | 6"     | bg_ss00.png          | B0DD          |
| Oasis 2          | 2017 | 1264 × 1680  | 300 | 7"     | bg_ss00.png          | B0DE,B0DF     |
| Oasis 3          | 2019 | 1264 × 1680  | 300 | 7"     | bg_ss00.png          | B0E0,B0E1     |

## Notes

- PW1/PW2 use `bg_medium_ss00.png` as the screensaver filename (verified
  via the `shuffless` utility); all other devices use `bg_ss00.png`.
- Empty serial prefix cells indicate models not yet tested — auto-detection
  falls back to parsing `eips -i` output for screen resolution.
- Kindle Scribe (10.2") is out of scope (different form factor).
- If your device is not listed, `device.sh` will attempt to detect the
  resolution via `eips -i`. Please report your serial prefix and
  resolution so it can be added.
