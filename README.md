# Android Display & Performance Optimizer

A lightweight, menu-driven Bash script to finely tune your Android device's display and performance settings via ADB (Android Debug Bridge). Quickly adjust animation scales, DPI, and hardware acceleration with simple, color-coded menus.

## Features

- **Device Management**: 
  - Automatically detects connected Android devices
  - Support for multiple connected devices with easy selection
  - Easy device switching

- **Animation Controls**:
  - View current animation settings
  - Set animation scales (0.0x, 0.75x, 0.9x, 1.0x, or custom values)
  - Quickly disable animations for improved performance

- **DPI Management**:
  - View current and default DPI information
  - Set custom DPI values
  - Reset DPI to device defaults

- **Hardware Acceleration**:
  - View detailed hardware acceleration status
  - Enable/disable all hardware acceleration features
  - Targeted control of GPU acceleration
  - Targeted control of UI hardware acceleration
  - Reset hardware acceleration to device defaults

- **Device Information**:
  - Display detailed device information
  - Show current hardware acceleration settings

- **Convenience Features**:
  - Simple menu-driven interface with color coding
  - Device reboot option with reconnection detection
  - Clear status messages with progress indicators

## Prerequisites

1. Bash shell (Linux, macOS, or Windows with WSL/Git Bash).
2. ADB installed and accessible in your PATH.
3. USB debugging enabled on your Android device.
4. USB connection between your computer and device.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/1999AZZAR/android-display-optimizer.git
   ```

2. Navigate to the project directory:
   ```bash
   cd android-display-optimizer
   ```

3. Make the script executable:
   ```bash
   chmod +x v6.sh
   ```

## Usage

1. Connect your Android device via USB and enable USB debugging.
2. Run the script:
   ```bash
   chmod +x v6.sh && ./v6.sh
   ```
3. Use number or letter keys to select menu options.
4. Press Enter to confirm selections when prompted.

## Menu Overview

Select from the following options:

### Information
- **1**: Show animation settings
- **2**: Show current DPI information
- **3**: Show device information
- **4**: Show hardware acceleration status

### Animation Controls
- **5**: Set animation scales to 1.0x (default)
- **6**: Set animation scales to 0.90x
- **7**: Set animation scales to 0.75x
- **8**: Set animation scales to custom value
- **9**: Turn off animations (0.0x)

### DPI Settings
- **10**: Set custom DPI
- **11**: Reset DPI to default

### Hardware Acceleration
- **12**: Enable all hardware acceleration features
- **13**: Enable GPU acceleration only
- **14**: Enable UI hardware acceleration only
- **15**: Disable all hardware acceleration features
- **16**: Disable GPU acceleration only
- **17**: Disable UI hardware acceleration only
- **18**: Reset hardware acceleration to device defaults

### Other
- **c**: Change device
- **r**: Reboot device
- **0**: Exit

## Important Notes

- Some changes may require a device restart to take full effect
- Changing DPI or hardware acceleration settings can affect device performance and appearance
- The script will automatically prompt when a reboot is recommended
- Always use caution when modifying system settings

## Troubleshooting

If you encounter issues:

1. Ensure ADB is properly installed and in your PATH
   ```bash
   adb version
   ```
2. Verify device connection:
   ```bash
   adb devices
   ```
3. Reconnect USB cable or restart ADB server if necessary:
   ```bash
   adb kill-server && adb start-server
   ```

## Contributing

Contributions welcome! Fork the repo, create a feature branch, and submit a Pull Request.
