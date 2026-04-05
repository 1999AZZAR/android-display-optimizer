# Android Display & Performance Optimizer

`v6.sh` is a Bash menu for changing common Android display and developer settings over ADB. It works with one or more connected devices and keeps a local `config.ini` plus optional `.bak` backups of captured settings.

## What it changes

- Animation scales
- Screen density (`wm density`)
- Screen timeout (`screen_off_timeout`)
- Screen brightness (`screen_brightness`)
- Stay-awake while charging (`stay_on_while_plugged_in`)
- Rotation and auto-rotation
- A small set of hardware acceleration and GPU debug properties
- Device reboot

## Requirements

- Bash
- `adb` in `PATH`
- USB debugging enabled on the Android device
- A connected device that appears as `device` in `adb devices`

## Install

```bash
git clone https://github.com/1999AZZAR/android-display-optimizer.git
cd android-display-optimizer
chmod +x v6.sh
```

## Run

```bash
./v6.sh
```

On startup the script:

1. Detects connected devices and asks you to choose one if more than one is available.
2. Creates `config.ini` if it does not exist yet.
3. Loads values from `config.ini`.
4. Shows the interactive menu.

## Menu summary

Information:
- Show animation settings
- Show display info
- Show device information
- Show hardware acceleration status
- Show rotation status

Display and animation:
- Set animation scale to `1.0`, `0.9`, `0.75`, custom, or `0.0`
- Set custom DPI
- Reset DPI

Screen timeout:
- Set screen timeout to `30 seconds`, `1 minute`, `2 minutes`, `5 minutes`, `10 minutes`, or `30 minutes`
- Keep short test presets for `7`, `10`, `15`, and `20` seconds
- Set a custom timeout in seconds

Brightness:
- Set brightness mode to manual or adaptive
- Set brightness to `64`, `128`, `192`, or a custom `0-255` value

Power:
- Disable stay-awake while charging
- Keep the screen awake while plugged in on `AC + USB`
- Keep the screen awake while plugged in on `AC + USB + wireless`

Rotation:
- Enable all rotations
- Disable upside-down rotation
- Toggle auto-rotation
- Lock rotation to portrait, landscape, upside-down, or reverse landscape

Hardware and GPU:
- Enable hardware acceleration related settings
- Disable them
- Reset them
- Toggle GPU profile rendering
- Toggle GPU overdraw debugging

Utility:
- Change selected device
- Reboot device
- Back up current settings to a timestamped `.bak` file
- Restore settings from a backup

## `config.ini`

The script generates `config.ini` from the current state of the selected device. It stores values the script can read and write directly.

Current sections:

- `[Animation]`
- `[Display]`
- `[Power]`
- `[HardwareAcceleration]`
- `[Rotation]`
- `[Backup]`
- `[Colors]`

Example:

```ini
[Animation]
window_animation_scale=1.0
transition_animation_scale=1.0
animator_duration_scale=1.0

[Display]
density=420
screen_off_timeout=15000
screen_brightness=128
screen_brightness_mode=0

[Power]
stay_on_while_plugged_in=0

[HardwareAcceleration]
force_gpu_rendering=1
profile_gpu_rendering=false
debug_gpu_overdraw=false

[Rotation]
accelerometer_rotation=1
user_rotation=0

[Backup]
Prefix=android_settings_
```

`[Colors]` is also written to the file and controls the terminal color codes used by the script.

## Notes on Android support

This script sends standard `adb shell settings`, `adb shell wm`, `adb shell cmd window`, and `adb shell setprop` commands. Android support is not uniform across devices and ROMs.

Examples:

- Some `setprop` targets are read-only.
- Some values require root.
- Some commands exist on one Android version and not another.

When one of those commands fails, `v6.sh` now prints the error and returns to the menu instead of exiting the script.

For commands with a capability probe, unsupported items are marked in the menu before you run them.

## Backups

`b` writes the current device state to a timestamped backup file using the prefix from `config.ini`.

`s` lists `*.bak` files in the current directory and applies the selected backup back to the device.

## Troubleshooting

If the script cannot see the device:

```bash
adb devices
```

If the device is listed as `unauthorized`, confirm the debugging prompt on the phone and run:

```bash
adb kill-server
adb start-server
adb devices
```

If a menu action fails:

- Read the ADB error message shown in the terminal.
- Check whether the setting exists on your Android version.
- Check whether the device or ROM requires root for that change.

## Repository files

- `v6.sh`: main script
- `config.ini`: generated local configuration

## Contributing

If you change the script, update the README when menu options, config keys, or command behavior changes.
