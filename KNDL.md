# Kindle internals

Notes on Kindle Lab126 internals discovered while developing this extension.

## WiFi reconnection after suspend

When the Kindle suspends, the WiFi radio is powered down regardless of the
`wirelessEnable` flag. The flag survives suspend as a software state, but the
actual radio state (`cmState`) drops to `NA`. After RTC wakeup, WiFi does not
automatically reconnect even though `wirelessEnable` is still `1`.

When the *user* wakes the Kindle (e.g. by pressing the power button), WiFi
reconnects within ~1 second. This fast path is triggered by the device
transitioning to Active state, which causes the `cmd` daemon to run its
`process_system_resume` handler and issue a reconnect to `wifid`.

### ensureConnection does not work in Screen Saver state

The `com.lab126.cmd` service exposes an `ensureConnection` property. Amazon's
own UI code (the Kindle Store search bar) calls it with an empty string to
speed up WiFi reconnection:

```
lipc-set-prop com.lab126.cmd ensureConnection ""
```

This is documented internally as a performance hack to start WiFi association
before the user finishes typing a search query. However, `ensureConnection`
only works when the device is in **Active** state. The `wifid` daemon discards
connection requests when the device is inactive:

```
W sysev:conn:action=request-discarded, reason=inactive:
```

Since our script runs after RTC wakeup in Screen Saver state (not Active),
`ensureConnection` is silently ignored and WiFi stays in `NA` state.

The `wifi:ESSID` variant of `ensureConnection` (used by the WiFi setup wizard)
has the same limitation. Additionally, `currentEssid` returns an empty string
when the radio is disconnected, so the ESSID is not available to pass.

### Why wifid rejects connections in Screen Saver state

The `wifid` daemon checks the device power state before processing any
connection request. In Screen Saver state the device is considered inactive
and `wifid` discards the request:

```
W sysev:conn:action=request-discarded, reason=inactive:
```

This gate applies to all connection paths that flow through `wifid`,
including `ensureConnection`, `wifid enable`, and `cmd` reconnect requests.

### The normal reconnection chain

When the user presses the power button:

1. `powerd` transitions to Active and fires `outOfScreenSaver`
2. `cmd` receives the event and runs `process_system_resume`
3. `cmd` checks `wirelessEnable` flag and calls `force_reconnect`
4. `cmd` sends a connect request to `wifid`
5. `wifid` sees device is Active, accepts the request, reconnects (~1s)

After RTC wakeup, `powerd` stays in Screen Saver -- step 1 never happens,
so the entire chain never fires.

### The wlan0 interface after suspend

After suspend, `ifconfig wlan0` shows the interface is UP but without the
RUNNING flag and without an IP address. The WiFi driver (Atheros AR6003) is
loaded but the radio firmware is in a low-power state and not scanning or
associating.

### Approaches tried

1. **Keep `wirelessEnable=1` across suspend** -- radio stays NA, never
   auto-reconnects in Screen Saver state.

2. **`ensureConnection ""`** -- discarded by `wifid` because device is
   inactive (Screen Saver state). This is how the Kindle Store search bar
   speeds up WiFi, but it only works when the device is already Active.

3. **`ensureConnection "wifi:ESSID"`** -- same problem, plus `currentEssid`
   returns empty when the radio is disconnected so there is no ESSID to pass.

4. **`wifid enable 1`** (KOReader approach) -- also discarded by `wifid`
   in Screen Saver state.

5. **`wpa_cli reconnect`** -- `wpa_supplicant` accepts the command (returns
   OK) but the radio firmware is powered down, so no actual association
   happens.

6. **`powerd wakeUp`** -- transitions to Active, WiFi reconnects fast (~1s),
   but the device stays Active and `eips` screen refresh is skipped (the
   update code skips `eips` when the device is Active to avoid disrupting the
   user).

7. **Spoofing `outOfScreenSaver` event** -- `cmd` receives it and triggers
   `force_reconnect`, but the request flows into `wifid` which checks the
   *actual* `powerd` state, finds it inactive, and discards.

8. **Toggle `wirelessEnable` 0 then 1** -- works reliably, takes 5-8 seconds
   for WiFi association. This bypasses the inactive gate because the full
   enable path reinitializes the radio hardware rather than issuing a
   connection request through `wifid`'s state-gated path.

### Conclusion

The `wirelessEnable` toggle is the only approach that works in Screen Saver
state. All "smart" reconnection paths are gated on the device being Active.
The 5-8 second association time is the cost of a full radio reinit, and there
is no shortcut available from Screen Saver state.

## Screensaver takeover via blanket

The `com.lab126.blanket` service manages the layered display stack. To take
over the screensaver layer and display a custom image, the system modules must
be unloaded first:

```
lipc-set-prop com.lab126.blanket unload splash
lipc-set-prop com.lab126.blanket unload screensaver
```

Without this, the blanket daemon may render its own screensaver on top of
whatever `eips` has drawn. The reverse (reloading) restores the system
screensaver when the custom image is no longer needed.

## Hibernate detection

The device supports two levels of sleep: SUSPEND_TO_MEM (light sleep, RAM
retained) and SUSPEND_TO_DISK (deep hibernate, RAM written to flash). powerd
switches to hibernate after the device has been suspended long enough (governed
by the `hibernate.s2h.rtc.secs` dynconfig key).

The file `/var/local/system/powerd/hibernate_session_tracker` is touched by
powerd when a hibernate cycle completes. Comparing its modification time to the
current time after a wakeup reveals whether the device hibernated rather than
light-slept. A recently modified tracker file combined with a suspend duration
over ~1 hour is a reliable signal that SUSPEND_TO_DISK occurred.

Setting a short RTC wakeup (less than the S2H threshold) prevents the device
from ever reaching hibernate, since powerd cancels the SUSPEND_TO_DISK
transition when a client RTC fires within its grace period.

## Distinguishing scheduled vs user-initiated wakeups

After an RTC wakeup the powerd `state` property briefly reads `screenSaver`
before transitioning to `active` if the user pressed a button. The wakeup
reason is exposed as `POWERD_WAKEUP_REASON_RTC` vs
`POWERD_WAKEUP_REASON_POWER_BUTTON` (and others) in powerd's internal state,
but this is not directly readable via LIPC.

A practical heuristic: record the intended wakeup epoch before suspending.
After waking, compare the current time against that epoch with a tolerance of
~90 seconds. If the wakeup falls within that window it was RTC-triggered; if it
is much earlier the user woke the device manually. There is also a ~15 second
settling period after wakeup before powerd's state is stable enough to
distinguish the two cases reliably.
