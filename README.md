# Android Display & Performance Optimizer

A highly configurable, menu-driven Bash script to finely tune your Android device's display and performance settings via ADB. Quickly adjust animation scales, DPI, screen rotation, and hardware acceleration with simple, color-coded menus.

## Features

- **Device Management**:
  - Automatically detects and supports multiple connected devices.
  - Allows for easy device switching without restarting the script.

- **Configuration Management**:
  - **Easy Customization**: Uses a simple `config.ini` file to let you define your own default values for the menu options.
  - **Automatic Setup**: Creates a default `config.ini` on the first run, so you can start immediately.
  - **Color Themes**: Customize the script's colors by editing the `[Colors]` section in `config.ini`.

- **Backup & Restore**:
  - **Save Settings**: Back up all current device settings (Animations, DPI, HW Acceleration, Rotation) to a timestamped `.bak` file.
  - **Restore Settings**: Easily list and apply settings from any previous backup, making it safe to experiment.
  - **Custom Backup Prefix**: Set a custom prefix for your backup files in `config.ini`.

- **Animation Controls**:
  - View current settings and instantly set them to common or custom values.
  - Quickly disable all animations (0.0x) for maximum performance.

- **Display & Rotation**:
  - View and manage DPI (screen density).
  - Full control over screen rotation, including locking to any orientation and toggling auto-rotation.

- **Hardware Acceleration & Debugging**:
  - View detailed hardware acceleration status.
  - Enable, disable, or reset all hardware acceleration features.
  - **Toggle GPU Profile Rendering**: An on-screen graph to visualize GPU rendering performance.
  - **Toggle GPU Overdraw Debugging**: Color-codes the screen to show where apps are drawing over the same area multiple times.

- **Device Utilities**:
  - Display detailed device information (Model, Android Version, etc.).
  - Simple, one-key device reboot with automatic reconnection detection.

## Prerequisites

1.  A Bash shell (standard on Linux/macOS; available on Windows via WSL or Git Bash).
2.  **ADB (Android Debug Bridge)** installed and accessible in your system's PATH.
3.  **USB Debugging** enabled in Developer Options on your Android device.
4.  A USB connection between your computer and your Android device.

## Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/1999AZZAR/android-display-optimizer.git
    ```

2.  Navigate into the project directory:
    ```bash
    cd android-display-optimizer
    ```

3.  Make the script executable:
    ```bash
    chmod +x v6.sh
    ```

## Usage

1.  Connect your Android device to your computer via USB.
2.  Run the script from your terminal:
    ```bash
    ./v6.sh
    ```
3.  On the first run, a `config.ini` file will be created for you.
4.  Use the number or letter keys to select an option from the menu.

## Configuration

This script uses a `config.ini` file to allow for easy customization. When you run the script for the first time, it will automatically generate this file with default values. You can edit this file to change the presets offered in the menu.

**Example `config.ini`:**
```ini
[AnimationScales]
Default = 1.0
Option1 = 0.9
Option2 = 0.75

[DPI]
Default = 480
Custom = 420

[Colors]
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

[Backup]
Prefix = android_settings_
```

## Menu Overview

The menu provides easy access to all features. New options for backup and restore have been added.

```
╔═════════════════════════════════════════════════╗
║       Android Display & Performance Optimizer    ║
╚═════════════════════════════════════════════════╝

SELECTED DEVICE: R58M456B76X (SM-A515F)
c. Change device   r. Reboot device   b. Backup settings
s. Restore settings                   0. Exit

--- INFORMATION ---
  1. Show animation settings      4. Show HW acceleration status
  2. Show current DPI info        5. Show rotation settings
  3. Show device information

--- ANIMATION (Using values from config.ini) ---
  6. Set animations to 1.0x       9. Set custom animation scale
  7. Set animations to 0.9x      10. Turn off animations (0.0x)
  8. Set animations to 0.75x

--- DISPLAY & ROTATION ---
 11. Set custom DPI              16. Lock rotation: Portrait
 12. Reset DPI to default        17. Lock rotation: Landscape
 13. Enable all rotations        18. Lock rotation: Upside-down
 14. Disable upside-down rot.    19. Lock rotation: Landscape (rev)
 15. Toggle auto-rotation

--- HARDWARE ACCELERATION & DEBUGGING ---
 20. Enable all HW acceleration      27. Toggle GPU Profile Rendering
 23. Disable all HW acceleration     28. Toggle GPU Overdraw Debug
 26. Reset HW acceleration to default

... and more options for Display, Rotation, and HW Acceleration.
```

## ⚠️ Important Notes & Disclaimer

-   **Use with caution.** Modifying system settings can impact device performance, stability, and appearance.
-   A **device restart** is often recommended for changes to take full effect.
-   The **backup** feature is your safety net. It is highly recommended to back up your settings before making significant changes.
-   The developers of this script are not responsible for any damage or issues that may arise from its use.

## Troubleshooting

If you encounter issues, try these steps:

1.  **Verify ADB**: Run `adb version` to ensure it's installed.
2.  **Check Connection**: Run `adb devices` to see if your device is listed and authorized.
3.  **Restart ADB Server**: Run `adb kill-server && adb start-server` to reset the connection.

## Contributing

Contributions are welcome! Fork the repo, create a feature branch, and submit a Pull Request.
