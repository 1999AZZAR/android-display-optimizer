# TODO

This file tracks command-set improvements for `v6.sh`. Keep tasks small and land them one at a time.

## Priority order

1. Brightness controls
2. Refresh rate controls
3. Immersive mode toggles
4. Better timeout presets
5. Stay-awake while charging
6. Font scaling
7. Command capability checks
8. Safe vs advanced menu split
9. Per-command fallback handling
10. Night mode controls

## Tasks

### 1. Brightness controls

Status: done

Add menu options for manual brightness and brightness mode.

Commands:

```bash
adb shell settings put system screen_brightness <0-255>
adb shell settings put system screen_brightness_mode 0
adb shell settings put system screen_brightness_mode 1
```

Implementation notes:

- Add current brightness info to the information section.
- Add fixed presets plus one custom value entry.
- Store brightness values in `config.ini`.
- Some devices may override manual brightness while adaptive mode is enabled.

### 2. Refresh rate controls

Status: pending

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

### 3. Immersive mode toggles

Status: pending

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

### 4. Better timeout presets

Status: done

Expand the current screen timeout menu with common real-world values.

Suggested presets:

- 30 seconds
- 1 minute
- 2 minutes
- 5 minutes
- 10 minutes
- 30 minutes

Implementation notes:

- Keep the current custom timeout input.
- Decide whether to keep the short `7/10/15/20` second presets or move them under an "advanced" or "short test" group.

### 5. Stay-awake while charging

Status: pending

Add controls for keeping the screen on while plugged in.

Commands:

```bash
adb shell settings put global stay_on_while_plugged_in 0
adb shell settings put global stay_on_while_plugged_in 3
adb shell settings put global stay_on_while_plugged_in 7
```

Implementation notes:

- `0` disables it.
- `3` usually means AC + USB.
- `7` usually means AC + USB + wireless.
- Add a short explanation in the menu or README.

### 6. Font scaling

Status: pending

Add controls for Android font scale.

Commands:

```bash
adb shell settings put system font_scale <value>
```

Implementation notes:

- Add fixed values like `0.85`, `1.0`, `1.15`, `1.3`.
- Add custom input.
- Store the value in `config.ini`.

### 7. Command capability checks

Status: pending

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

### 8. Safe vs advanced menu split

Status: pending

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

### 9. Per-command fallback handling

Status: pending

Improve grouped actions so one failing command does not make the whole action look like a complete failure.

Implementation notes:

- Run each command in a guarded helper.
- Print which sub-step failed.
- Print whether the overall action was full success, partial success, or failed.
- Apply this first to hardware acceleration actions.

### 10. Night mode controls

Status: pending

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
