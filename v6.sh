#!/usr/bin/env bash
set -euo pipefail
if ! command -v adb >/dev/null 2>&1; then
    echo -e "${RED}ADB is required but not installed. Please install ADB and ensure it's in your PATH.${RESET}"
    exit 1
fi

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

# Global variable for selected device
SELECTED_DEVICE=""

# Function to check and select device
check_and_select_device() {
    echo -e "${BLUE}Checking for connected devices...${RESET}"

    # Get list of devices
    DEVICE_LIST=($(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}'))
    DEVICE_COUNT=${#DEVICE_LIST[@]}

    if [ $DEVICE_COUNT -eq 0 ]; then
        echo -e "${RED}No devices connected. Please connect a device and try again.${RESET}"
        exit 1
    elif [ $DEVICE_COUNT -eq 1 ]; then
        SELECTED_DEVICE=${DEVICE_LIST[0]}
        echo -e "${GREEN}✓ Using device: $SELECTED_DEVICE${RESET}"
    else
        echo -e "${YELLOW}Multiple devices found:${RESET}"
        for i in "${!DEVICE_LIST[@]}"; do
            DEVICE=${DEVICE_LIST[$i]}
            MODEL=$(adb -s $DEVICE shell getprop ro.product.model 2>/dev/null | tr -d '\r')
            echo -e "  ${BOLD}$((i + 1))${RESET}. $DEVICE ${YELLOW}($MODEL)${RESET}"
        done

        while true; do
            echo -ne "${BOLD}Select device (1-$DEVICE_COUNT): ${RESET}"
            read selection

            if [[ $selection =~ ^[0-9]+$ ]] && [ $selection -ge 1 ] && [ $selection -le $DEVICE_COUNT ]; then
                SELECTED_DEVICE=${DEVICE_LIST[$((selection - 1))]}
                echo -e "${GREEN}✓ Selected device: $SELECTED_DEVICE${RESET}"
                break
            else
                echo -e "${RED}Invalid selection. Please try again.${RESET}"
            fi
        done
    fi
    echo
}

# Function to run ADB command on selected device
run_adb() {
    adb -s $SELECTED_DEVICE $@
}

# Function to get current animation settings
get_animation_settings() {
    echo -e "${BOLD}Current Animation Settings:${RESET}"
    echo -e "Window animation scale: ${GREEN}$(run_adb shell settings get global window_animation_scale)${RESET}"
    echo -e "Transition animation scale: ${GREEN}$(run_adb shell settings get global transition_animation_scale)${RESET}"
    echo -e "Animator duration scale: ${GREEN}$(run_adb shell settings get global animator_duration_scale)${RESET}"
    echo
}

# Function to get DPI information
get_dpi_info() {
    CURRENT_DPI=$(run_adb shell wm density | grep -oE '[0-9]+' | head -1)
    DEFAULT_DPI=$(run_adb shell getprop ro.sf.lcd_density)

    echo -e "${BOLD}DPI Information:${RESET}"
    echo -e "Current DPI: ${GREEN}$CURRENT_DPI${RESET}"
    echo -e "Default DPI: ${GREEN}$DEFAULT_DPI${RESET}"
    echo
}

# Function to get hardware acceleration status
get_hw_acceleration_status() {
    # Check different hardware acceleration settings
    HW_ACCEL_GENERAL=$(run_adb shell getprop debug.hwui.render_dirty_regions 2>/dev/null | tr -d '\r')
    HW_ACCEL_GPU=$(run_adb shell getprop ro.config.hw_quickpoweron 2>/dev/null | tr -d '\r')
    HW_GPU_FORCE=$(run_adb shell settings get global force_gpu_rendering 2>/dev/null | tr -d '\r')
    HW_ACCEL_UI=$(run_adb shell getprop persist.sys.ui.hw 2>/dev/null | tr -d '\r')
    HW_ACCEL_DEVELOPER=$(run_adb shell settings get global hardware_accelerated_rendering 2>/dev/null | tr -d '\r')
    HW_GPU_USE=$(run_adb shell getprop debug.egl.hw 2>/dev/null | tr -d '\r')
    HW_GPU_PROFILER=$(run_adb shell getprop debug.egl.profiler 2>/dev/null | tr -d '\r')
    HW_OPENGL_TRACES=$(run_adb shell getprop debug.egl.trace 2>/dev/null | tr -d '\r')

    echo -e "${BOLD}Hardware Acceleration Status:${RESET}"
    echo -e "HW Rendering: ${GREEN}${HW_ACCEL_GENERAL:-"Not set"}${RESET}"
    echo -e "GPU Acceleration: ${GREEN}${HW_ACCEL_GPU:-"Not set"}${RESET}"
    echo -e "Force GPU Rendering: ${GREEN}${HW_GPU_FORCE:-"Not set"}${RESET}"
    echo -e "UI Hardware Acceleration: ${GREEN}${HW_ACCEL_UI:-"Not set"}${RESET}"
    echo -e "Developer Settings HW Accel: ${GREEN}${HW_ACCEL_DEVELOPER:-"Not set"}${RESET}"
    echo -e "GPU Usage: ${GREEN}${HW_GPU_USE:-"Not set"}${RESET}"
    echo -e "GPU Profiler: ${GREEN}${HW_GPU_PROFILER:-"Not set"}${RESET}"
    echo -e "OpenGL Traces: ${GREEN}${HW_OPENGL_TRACES:-"Not set"}${RESET}"
    echo
}

# Function to get rotation settings
get_rotation_settings() {
    # Get current rotation settings
    ACCELEROMETER_ROTATION=$(run_adb shell settings get system accelerometer_rotation | tr -d '\r')
    USER_ROTATION=$(run_adb shell settings get system user_rotation | tr -d '\r')
    ACCELEROMETER_ROTATION_STATUS="Disabled"
    USER_ROTATION_VALUE="Unknown"

    if [ "$ACCELEROMETER_ROTATION" == "1" ]; then
        ACCELEROMETER_ROTATION_STATUS="Enabled"
    fi

    case "$USER_ROTATION" in
        "0") USER_ROTATION_VALUE="Portrait (0°)" ;;
        "1") USER_ROTATION_VALUE="Landscape (90°)" ;;
        "2") USER_ROTATION_VALUE="Upside down (180°)" ;;
        "3") USER_ROTATION_VALUE="Landscape reversed (270°)" ;;
        *) USER_ROTATION_VALUE="Unknown ($USER_ROTATION)" ;;
    esac

    # Check if upside-down rotation is allowed
    ALLOWED_ROTATIONS=$(run_adb shell cmd window get-allowed-display-rotations | tr -d '\r')
    UPSIDE_DOWN_ALLOWED="No"

    if [[ $ALLOWED_ROTATIONS == *"180"* ]]; then
        UPSIDE_DOWN_ALLOWED="Yes"
    fi

    echo -e "${BOLD}Current Rotation Settings:${RESET}"
    echo -e "Auto-Rotation: ${GREEN}$ACCELEROMETER_ROTATION_STATUS${RESET}"
    echo -e "Current Fixed Rotation: ${GREEN}$USER_ROTATION_VALUE${RESET}"
    echo -e "Upside-Down Rotation Allowed: ${GREEN}$UPSIDE_DOWN_ALLOWED${RESET}"
    echo
}

# Function to enable all rotations including upside-down
enable_all_rotations() {
    echo -e "${BLUE}Enabling all screen rotations (including upside-down)...${RESET}"

    # Enable all rotations
    run_adb shell content insert --uri content://settings/system --bind name:s:user_rotation_angles_global --bind value:s:0,1,2,3

    # Need to use the window manager command to enable upside-down rotation
    run_adb shell cmd window set-allowed-display-rotations 0,1,2,3

    echo -e "${GREEN}✓ All screen rotations enabled${RESET}"
    echo -e "${BOLD}Note: You may need to toggle auto-rotation for changes to take effect${RESET}"
    echo
}

# Function to disable upside-down rotation
disable_upside_down_rotation() {
    echo -e "${BLUE}Disabling upside-down rotation...${RESET}"

    # Disable upside-down rotation
    run_adb shell content insert --uri content://settings/system --bind name:s:user_rotation_angles_global --bind value:s:0,1,3

    # Need to use the window manager command to disable upside-down rotation
    run_adb shell cmd window set-allowed-display-rotations 0,1,3

    echo -e "${GREEN}✓ Upside-down rotation disabled${RESET}"
    echo -e "${BOLD}Note: You may need to toggle auto-rotation for changes to take effect${RESET}"
    echo
}

# Function to set rotation to a specific orientation
set_specific_rotation() {
    ROTATION=$1
    ROTATION_NAME=""

    case "$ROTATION" in
        "0") ROTATION_NAME="Portrait (0°)" ;;
        "1") ROTATION_NAME="Landscape (90°)" ;;
        "2") ROTATION_NAME="Upside down (180°)" ;;
        "3") ROTATION_NAME="Landscape reversed (270°)" ;;
    esac

    echo -e "${BLUE}Setting rotation to ${ROTATION_NAME}...${RESET}"

    # Disable auto-rotation
    run_adb shell settings put system accelerometer_rotation 0

    # Set specific rotation
    run_adb shell settings put system user_rotation $ROTATION

    echo -e "${GREEN}✓ Rotation set to ${ROTATION_NAME}${RESET}"
    echo
}

# Function to toggle auto-rotation
toggle_auto_rotation() {
    CURRENT_AUTO_ROTATION=$(run_adb shell settings get system accelerometer_rotation | tr -d '\r')

    if [ "$CURRENT_AUTO_ROTATION" == "1" ]; then
        # Disable auto-rotation
        run_adb shell settings put system accelerometer_rotation 0
        echo -e "${GREEN}✓ Auto-rotation disabled${RESET}"
    else
        # Enable auto-rotation
        run_adb shell settings put system accelerometer_rotation 1
        echo -e "${GREEN}✓ Auto-rotation enabled${RESET}"
    fi
    echo
}

# Function to get device information
get_device_info() {
    echo -e "${BOLD}Device Information:${RESET}"
    echo -e "Device ID: ${GREEN}$SELECTED_DEVICE${RESET}"
    echo -e "Device Model: ${GREEN}$(run_adb shell getprop ro.product.model)${RESET}"
    echo -e "Android Version: ${GREEN}$(run_adb shell getprop ro.build.version.release)${RESET}"
    echo -e "SDK Version: ${GREEN}$(run_adb shell getprop ro.build.version.sdk)${RESET}"
    echo -e "Screen Resolution: ${GREEN}$(run_adb shell wm size)${RESET}"

    get_hw_acceleration_status
}

# Function to set animation scales
set_animation_scale() {
    SCALE=$1
    echo -e "${BLUE}Setting all animation scales to ${SCALE}x${RESET}"
    run_adb shell settings put global window_animation_scale $SCALE
    run_adb shell settings put global transition_animation_scale $SCALE
    run_adb shell settings put global animator_duration_scale $SCALE
    echo -e "${GREEN}✓ Animation scales set to ${SCALE}x${RESET}"
    echo
}

# Function to set custom DPI
set_custom_dpi() {
    NEW_DPI=$1
    echo -e "${BLUE}Setting device DPI to $NEW_DPI${RESET}"
    run_adb shell wm density $NEW_DPI
    echo -e "${GREEN}✓ DPI set to $NEW_DPI${RESET}"
    echo -e "${BOLD}Note: You may need to restart your device for changes to take full effect${RESET}"
    echo
}

# Function to reset DPI to default
reset_dpi() {
    echo -e "${BLUE}Resetting DPI to device default${RESET}"
    run_adb shell wm density reset
    echo -e "${GREEN}✓ DPI reset to default${RESET}"
    echo -e "${BOLD}Note: You may need to restart your device for changes to take full effect${RESET}"
    echo
}

# Function to enable all hardware acceleration
enable_all_hw_acceleration() {
    echo -e "${BLUE}Enabling all hardware acceleration features...${RESET}"

    # Set properties that control hardware acceleration
    run_adb shell setprop debug.hwui.render_dirty_regions true
    run_adb shell setprop persist.sys.ui.hw 1
    run_adb shell settings put global hardware_accelerated_rendering 1
    run_adb shell settings put global force_gpu_rendering 1
    run_adb shell setprop debug.egl.hw 1
    run_adb shell setprop ro.config.hw_quickpoweron 1

    echo -e "${GREEN}✓ All hardware acceleration features enabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to enable only GPU acceleration
enable_gpu_acceleration() {
    echo -e "${BLUE}Enabling GPU acceleration...${RESET}"

    # Set GPU-specific properties
    run_adb shell settings put global force_gpu_rendering 1
    run_adb shell setprop debug.egl.hw 1
    run_adb shell setprop ro.config.hw_quickpoweron 1

    echo -e "${GREEN}✓ GPU acceleration enabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to enable only UI hardware acceleration
enable_ui_hw_acceleration() {
    echo -e "${BLUE}Enabling UI hardware acceleration...${RESET}"

    # Set UI-specific properties
    run_adb shell setprop persist.sys.ui.hw 1
    run_adb shell setprop debug.hwui.render_dirty_regions true

    echo -e "${GREEN}✓ UI hardware acceleration enabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to disable all hardware acceleration
disable_all_hw_acceleration() {
    echo -e "${BLUE}Disabling all hardware acceleration features...${RESET}"

    # Disable hardware acceleration properties
    run_adb shell setprop debug.hwui.render_dirty_regions false
    run_adb shell setprop persist.sys.ui.hw 0
    run_adb shell settings put global hardware_accelerated_rendering 0
    run_adb shell settings put global force_gpu_rendering 0
    run_adb shell setprop debug.egl.hw 0
    run_adb shell setprop ro.config.hw_quickpoweron 0

    echo -e "${GREEN}✓ All hardware acceleration features disabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to disable only GPU acceleration
disable_gpu_acceleration() {
    echo -e "${BLUE}Disabling GPU acceleration...${RESET}"

    # Disable GPU-specific properties
    run_adb shell settings put global force_gpu_rendering 0
    run_adb shell setprop debug.egl.hw 0
    run_adb shell setprop ro.config.hw_quickpoweron 0

    echo -e "${GREEN}✓ GPU acceleration disabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to disable only UI hardware acceleration
disable_ui_hw_acceleration() {
    echo -e "${BLUE}Disabling UI hardware acceleration...${RESET}"

    # Disable UI-specific properties
    run_adb shell setprop persist.sys.ui.hw 0
    run_adb shell setprop debug.hwui.render_dirty_regions false

    echo -e "${GREEN}✓ UI hardware acceleration disabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to reset hardware acceleration to device defaults
reset_hw_acceleration() {
    echo -e "${BLUE}Resetting hardware acceleration to device defaults...${RESET}"

    # Remove any custom property settings
    run_adb shell setprop debug.hwui.render_dirty_regions ""
    run_adb shell setprop persist.sys.ui.hw ""
    run_adb shell settings delete global hardware_accelerated_rendering
    run_adb shell settings delete global force_gpu_rendering
    run_adb shell setprop debug.egl.hw ""
    run_adb shell setprop ro.config.hw_quickpoweron ""

    echo -e "${GREEN}✓ Hardware acceleration reset to system defaults${RESET}"
    echo -e "${BOLD}Note: A device restart is recommended for changes to take full effect${RESET}"
    echo
}

# Function to reboot device
reboot_device() {
    echo -e "${YELLOW}Rebooting device $SELECTED_DEVICE...${RESET}"
    run_adb reboot
    echo -e "${GREEN}✓ Reboot command sent${RESET}"
    echo -e "${BOLD}Device is now restarting...${RESET}"
    echo -e "${BLUE}Please wait for the device to reconnect before continuing${RESET}"
    echo
    echo -e "${YELLOW}Would you like to wait for the device to reconnect? (y/n)${RESET}"
    read wait_response

    if [[ "$wait_response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Waiting for device to reconnect...${RESET}"
        adb -s $SELECTED_DEVICE wait-for-device
        echo -e "${GREEN}✓ Device reconnected!${RESET}"
    else
        echo -e "${YELLOW}You'll need to restart this script after your device has rebooted${RESET}"
        exit 0
    fi
}

# Function to change device
change_device() {
    check_and_select_device
}

# Display menu
show_menu() {
    clear
    echo -e "${BOLD}╔═════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║       Android Display & Performance Optimizer    ║${RESET}"
    echo -e "${BOLD}╚═════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${BOLD}SELECTED DEVICE:${RESET} ${GREEN}$SELECTED_DEVICE${RESET} ($(run_adb shell getprop ro.product.model | tr -d '\r'))"
    echo -e "${YELLOW}c. Change device${RESET}     ${RED}r. Reboot device${RESET}"
    echo
    echo -e "${BOLD}INFORMATION:${RESET}"
    echo -e "  1. Show animation settings"
    echo -e "  2. Show current DPI information"
    echo -e "  3. Show device information"
    echo -e "  4. Show hardware acceleration status"
    echo -e "  5. Show rotation settings"
    echo
    echo -e "${BOLD}ANIMATION SETTINGS:${RESET}"
    echo -e "  6. Set animation scales to 1.0x (default)"
    echo -e "  7. Set animation scales to 0.90x"
    echo -e "  8. Set animation scales to 0.75x"
    echo -e "  9. Set animation scales to custom value"
    echo -e " 10. Turn off animations (0.0x)"
    echo
    echo -e "${BOLD}DPI SETTINGS:${RESET}"
    echo -e " 11. Set custom DPI"
    echo -e " 12. Reset DPI to default"
    echo
    echo -e "${BOLD}ROTATION SETTINGS:${RESET}"
    echo -e " 13. Enable all rotations (including upside-down)"
    echo -e " 14. Disable upside-down rotation"
    echo -e " 15. Toggle auto-rotation"
    echo -e " 16. Set rotation to portrait (0°)"
    echo -e " 17. Set rotation to landscape (90°)"
    echo -e " 18. Set rotation to upside-down (180°)"
    echo -e " 19. Set rotation to landscape reversed (270°)"
    echo
    echo -e "${BOLD}HARDWARE ACCELERATION:${RESET}"
    echo -e " 20. Enable all hardware acceleration features"
    echo -e " 21. Enable GPU acceleration only"
    echo -e " 22. Enable UI hardware acceleration only"
    echo -e " 23. Disable all hardware acceleration features"
    echo -e " 24. Disable GPU acceleration only"
    echo -e " 25. Disable UI hardware acceleration only"
    echo -e " 26. Reset hardware acceleration to device defaults"
    echo
    echo -e "${BOLD}OTHER:${RESET}"
    echo -e "  0. Exit"
    echo
    echo -e "${BOLD}Select an option: ${RESET}"
}

# Function to wait for user confirmation
wait_for_enter() {
    echo -e "Press Enter to continue"
    read
}

# Main program
check_and_select_device

# Main loop
while true; do
    show_menu
    read choice

    case $choice in
    0)
        echo -e "${GREEN}Exiting...${RESET}"
        exit 0
        ;;
    c | C)
        change_device
        ;;
    r | R)
        reboot_device
        wait_for_enter
        ;;
    1)
        get_animation_settings
        wait_for_enter
        ;;
    2)
        get_dpi_info
        wait_for_enter
        ;;
    3)
        get_device_info
        wait_for_enter
        ;;
    4)
        get_hw_acceleration_status
        wait_for_enter
        ;;
    5)
        get_rotation_settings
        wait_for_enter
        ;;
    6)
        set_animation_scale 1.0
        wait_for_enter
        ;;
    7)
        set_animation_scale 0.90
        wait_for_enter
        ;;
    8)
        set_animation_scale 0.75
        wait_for_enter
        ;;
    9)
        echo -n -e "${BOLD}Enter custom scale (e.g., 0.5): ${RESET}"
        read custom_scale
        set_animation_scale $custom_scale
        wait_for_enter
        ;;
    10)
        set_animation_scale 0.0
        echo -e "${GREEN}✓ Animations turned off (0.0x)${RESET}"
        wait_for_enter
        ;;
    11)
        get_dpi_info
        echo -n -e "${BOLD}Enter new DPI value: ${RESET}"
        read new_dpi
        set_custom_dpi $new_dpi
        wait_for_enter
        ;;
    12)
        reset_dpi
        wait_for_enter
        ;;
    13)
        enable_all_rotations
        wait_for_enter
        ;;
    14)
        disable_upside_down_rotation
        wait_for_enter
        ;;
    15)
        toggle_auto_rotation
        wait_for_enter
        ;;
    16)
        set_specific_rotation 0
        wait_for_enter
        ;;
    17)
        set_specific_rotation 1
        wait_for_enter
        ;;
    18)
        set_specific_rotation 2
        wait_for_enter
        ;;
    19)
        set_specific_rotation 3
        wait_for_enter
        ;;
    20)
        enable_all_hw_acceleration
        wait_for_enter
        ;;
    21)
        enable_gpu_acceleration
        wait_for_enter
        ;;
    22)
        enable_ui_hw_acceleration
        wait_for_enter
        ;;
    23)
        disable_all_hw_acceleration
        wait_for_enter
        ;;
    24)
        disable_gpu_acceleration
        wait_for_enter
        ;;
    25)
        disable_ui_hw_acceleration
        wait_for_enter
        ;;
    26)
        reset_hw_acceleration
        wait_for_enter
        ;;
    *)
        echo -e "${RED}Invalid option. Please try again.${RESET}"
        sleep 2
        ;;
    esac
done
