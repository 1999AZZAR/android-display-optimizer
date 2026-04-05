# TODO

This file tracks the remaining work for `v6.sh`.

Priority scale:

- `P1`: correctness, safety, or restore-path problems
- `P2`: high-value features that are broadly useful
- `P3`: useful but more device-dependent or niche
- `P4`: cleanup and structure work

## P1

No open P1 items right now.

## P2

### Refresh rate controls

Why:
- High-value display control on devices that support variable refresh rate.
- Official Android platform docs describe `Settings.System.PEAK_REFRESH_RATE` and `Settings.System.MIN_REFRESH_RATE` as runtime-configurable settings.

Commands:

```bash
adb shell settings put system peak_refresh_rate <hz>
adb shell settings put system min_refresh_rate <hz>
adb shell settings put system user_refresh_rate <hz>
```

Suggested scope:
- Show current refresh-rate related settings in the info section.
- Add a few common presets such as `60`, `90`, `120`.
- Add a reset path.
- Gate the menu behind capability detection.

Platform caveats:
- Support varies by device and ROM.
- Android power saver can clamp refresh rate to `60Hz` or lower even when the setting exists.

### Immersive mode toggles

Why:
- Still a useful display control for testing and kiosk-like use.

Commands:

```bash
adb shell settings put global policy_control immersive.full=*
adb shell settings put global policy_control immersive.navigation=*
adb shell settings put global policy_control immersive.status=*
adb shell settings delete global policy_control
```

Suggested scope:
- Full immersive
- Hide navigation only
- Hide status only
- Reset

Platform caveats:
- This behavior is not consistent across newer Android builds.
- Must be gated behind a capability check.

### Night mode controls

Why:
- Broadly useful and lower risk than performance-related commands.

Commands:

```bash
adb shell cmd uimode night yes
adb shell cmd uimode night no
adb shell cmd uimode night auto
```

Suggested scope:
- Add simple on, off, and auto options.
- Add a capability probe first.

## P3

### Stay-awake expansion

Why:
- The current stay-awake options cover common plug states but not the full bitmask range.

Current implementation:

```bash
adb shell settings put global stay_on_while_plugged_in 0
adb shell settings put global stay_on_while_plugged_in 3
adb shell settings put global stay_on_while_plugged_in 7
```

Possible follow-up:
- Add dock-aware or custom bitmask options where supported.
- Add a readout in device info or display info for the current stay-awake state.

### Fixed performance mode

Why:
- Useful for repeatable testing on supported devices.
- Official Android Developers docs expose this through `cmd power`.

Command:

```bash
adb shell cmd power set-fixed-performance-mode-enabled [true|false]
```

Suggested scope:
- Keep this clearly marked as advanced or test-only.
- Gate it behind capability detection.

Platform caveats:
- Android Developers documents it for Android 11+.
- It is intended for benchmarking and does not guarantee thermal stability.

## P4

### Safe vs advanced menu split

Why:
- The menu has grown enough that low-risk display changes and failure-prone debug controls should be separated.

Safe candidates:
- Animation scale
- DPI
- Screen timeout
- Brightness
- Font scale
- Rotation

Advanced candidates:
- `setprop` hardware toggles
- GPU debugging
- Immersive mode
- Refresh rate overrides
- Fixed performance mode

Goal:
- Make the default workflow cleaner.
- Keep risky or device-dependent commands in a clearly marked section.

## Notes from the latest review

Code findings that should influence future work:

- Restore/apply is now schema-sensitive because more keys are being added over time.
- Full device info relies on interface-specific parsing like `wlan0`; this is acceptable for now but should stay best-effort, not required.
- Hardware grouped actions are better than before, but status propagation still needs refinement.

Research-backed command candidates worth keeping on the roadmap:

- Refresh rate: `peak_refresh_rate`, `min_refresh_rate`, `user_refresh_rate`
- Immersive mode: `policy_control`
- Night mode: `cmd uimode night`
- Fixed performance mode: `cmd power set-fixed-performance-mode-enabled`

## Working rules

- Update `README.md` when menu options or config keys change.
- Add capability probes before exposing device-dependent features.
- Prefer additive changes over large menu rewrites.
- Commit one task at a time.
