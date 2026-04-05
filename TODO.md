# TODO

This file tracks command-set improvements for `v6.sh`. Keep tasks small and land them one at a time.

## Priority order

1. Refresh rate controls
2. Immersive mode toggles
3. Command capability checks
4. Safe vs advanced menu split
5. Night mode controls

## Tasks

### 1. Refresh rate controls

Add refresh-rate controls for supported devices.

Commands:

```bash
adb shell settings put system peak_refresh_rate <hz>
adb shell settings put system min_refresh_rate <hz>
adb shell settings put system user_refresh_rate <hz>
```

Implementation notes:

- Device support varies a lot.
- Some devices ignore one or more of these keys.
- This should be guarded with capability checks before exposing the options.

### 2. Immersive mode toggles

Add fullscreen and immersive mode shortcuts.

Commands:

```bash
adb shell settings put global policy_control immersive.full=*
adb shell settings put global policy_control immersive.navigation=*
adb shell settings put global policy_control immersive.status=*
adb shell settings delete global policy_control
```

Implementation notes:

- Add a reset option.
- Some newer Android versions may ignore this behavior.
- Document that this is global and affects the whole UI.

### 3. Command capability checks

Detect whether a command or settings key is supported before showing or applying options.

Examples:

```bash
adb shell cmd window -h
adb shell settings get system peak_refresh_rate
adb shell settings get global policy_control
```

Implementation notes:

- Prefer checks that do not modify state.
- Show unsupported items as hidden or clearly marked.
- This matters most for hardware, immersive mode, and refresh rate options.

### 4. Safe vs advanced menu split

Separate common settings from risky or failure-prone ones.

Safe candidates:

- Animation scale
- DPI
- Screen timeout
- Brightness
- Rotation

Advanced candidates:

- `setprop` hardware toggles
- GPU debugging
- Immersive mode
- Refresh rate overrides

Implementation notes:

- This can be done as separate sections in one menu.
- Keep the current numbering stable where practical.

### 5. Night mode controls

Add Android night mode shortcuts.

Commands:

```bash
adb shell cmd uimode night yes
adb shell cmd uimode night no
adb shell cmd uimode night auto
```

Implementation notes:

- Command support depends on Android version.
- Keep this lower priority than brightness and capability checks.

## Rules for future tasks

- Update `README.md` when menu options or config keys change.
- Keep new command groups behind capability checks when Android support is inconsistent.
- Prefer additive changes over large menu rewrites.
- Commit one task at a time.
